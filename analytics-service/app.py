import json
import os
import queue
import random
import threading
import time
from collections import Counter
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Dict, Tuple

from confluent_kafka import Consumer, KafkaError

import firebase_admin
from firebase_admin import credentials, firestore
from google.api_core.exceptions import DeadlineExceeded, ResourceExhausted, ServiceUnavailable

from shared.kafka_config import KafkaConfigError, build_kafka_conf


FIREBASE_KEY_PATH = os.getenv("FIREBASE_KEY_PATH", "/app/serviceAccountKey.json")

STORE_RAW_EVENTS = os.getenv("STORE_RAW_EVENTS", "false").lower() == "true"

WINDOW_SEC = int(os.getenv("WINDOW_SEC", "10"))

FIRESTORE_MAX_RETRIES = int(os.getenv("FIRESTORE_MAX_RETRIES", "8"))
FIRESTORE_BACKOFF_BASE_SEC = float(os.getenv("FIRESTORE_BACKOFF_BASE_SEC", "0.5"))
FIRESTORE_BACKOFF_MAX_SEC = float(os.getenv("FIRESTORE_BACKOFF_MAX_SEC", "8.0"))

PRINT_LOCAL_STATS = os.getenv("PRINT_LOCAL_STATS", "true").lower() == "true"


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


def day_str(dt: datetime) -> str:
    return dt.astimezone(timezone.utc).strftime("%Y-%m-%d")


def window_bucket_ts(dt: datetime, window_sec: int) -> str:
    epoch = int(dt.timestamp())
    bucket_start = epoch - (epoch % window_sec)
    return datetime.fromtimestamp(bucket_start, tz=timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def get_site_id(event: dict) -> int:
    try:
        return int(event.get("site_id", 1))
    except Exception:
        return 1


def init_firestore():
    if not firebase_admin._apps:
        cred = credentials.Certificate(FIREBASE_KEY_PATH)
        firebase_admin.initialize_app(cred)
    return firestore.client()


def _firestore_retry_sleep(attempt: int) -> float:
    base = min(FIRESTORE_BACKOFF_MAX_SEC, FIRESTORE_BACKOFF_BASE_SEC * (2 ** attempt))
    jitter = random.uniform(0.0, base * 0.2)
    return base + jitter


def _commit_batch_with_retry(batch, label: str) -> bool:
    for attempt in range(FIRESTORE_MAX_RETRIES):
        try:
            batch.commit()
            return True
        except (ResourceExhausted, DeadlineExceeded, ServiceUnavailable) as e:
            wait = _firestore_retry_sleep(attempt)
            print(f"[FIRESTORE][{label}] retryable error: {type(e).__name__}: {e} (sleep {wait:.2f}s)")
            time.sleep(wait)
        except Exception as e:
            print(f"[FIRESTORE][{label}] non-retryable error: {type(e).__name__}: {e}")
            return False
    print(f"[FIRESTORE][{label}] giving up after {FIRESTORE_MAX_RETRIES} retries")
    return False


def write_raw_event(db, event: dict, kafka_meta: dict):
    if not STORE_RAW_EVENTS:
        return
    doc = {
        "event": event,
        "kafka": kafka_meta,
        "ingested_at": firestore.SERVER_TIMESTAMP,
        "site_id": get_site_id(event),
    }
    db.collection("raw_events").add(doc)


@dataclass(frozen=True)
class WindowPayload:
    created_at: datetime
    window_start: str
    window_sec: int
    per_site_counts: Dict[int, Dict[str, int]]
    per_site_amount: Dict[int, int]


class FirestoreWriter(threading.Thread):
    def __init__(self, db, q: "queue.Queue[WindowPayload]"):
        super().__init__(daemon=True)
        self.db = db
        self.q = q

    def run(self):
        while True:
            payload = self.q.get()
            try:
                self._write_payload(payload)
            except Exception as e:
                print(f"[FIRESTORE][writer] unexpected error: {type(e).__name__}: {e}")
            finally:
                self.q.task_done()

    def _write_payload(self, payload: WindowPayload):
        dt = payload.created_at
        d = day_str(dt)

        for site_id, counts in payload.per_site_counts.items():
            amount_total = int(payload.per_site_amount.get(site_id, 0))

            lifetime_ref = self.db.collection("agg_lifetime").document(f"site_{site_id}")
            daily_ref = self.db.collection("agg_daily").document(f"site_{site_id}_{d}")
            window_ref = self.db.collection("agg_window").document(f"site_{site_id}_{payload.window_start}")

            counts_increments = {k: firestore.Increment(int(v)) for k, v in counts.items()}

            batch = self.db.batch()

            batch.set(
                lifetime_ref,
                {
                    "site_id": site_id,
                    "updated_at": firestore.SERVER_TIMESTAMP,
                    "counts": counts_increments,
                    "amount_total": firestore.Increment(amount_total),
                },
                merge=True,
            )

            batch.set(
                daily_ref,
                {
                    "site_id": site_id,
                    "day": d,
                    "updated_at": firestore.SERVER_TIMESTAMP,
                    "counts": counts_increments,
                    "amount_total": firestore.Increment(amount_total),
                },
                merge=True,
            )

            batch.set(
                window_ref,
                {
                    "site_id": site_id,
                    "window_start": payload.window_start,
                    "window_sec": payload.window_sec,
                    "counts": {k: int(v) for k, v in counts.items()},
                    "amount_total": amount_total,
                    "updated_at": firestore.SERVER_TIMESTAMP,
                },
                merge=True,
            )

            ok = _commit_batch_with_retry(batch, label=f"batch_site_{site_id}")
            if not ok:
                print(f"[FIRESTORE][writer] failed batch for site_id={site_id}")


def main() -> int:
    db = init_firestore()

    topic = os.getenv("TOPIC", "events")
    group_id = os.getenv("GROUP_ID", "analytics-group")
    auto_offset_reset = os.getenv("AUTO_OFFSET_RESET", "earliest")
    proto = os.getenv("KAFKA_SECURITY_PROTOCOL", "ssl").lower()

    base = {
        "group.id": group_id,
        "auto.offset.reset": auto_offset_reset,
        "enable.auto.commit": True,
        "session.timeout.ms": 15000,
        "max.poll.interval.ms": 900000,
    }

    try:
        conf = build_kafka_conf(base=base)
    except KafkaConfigError as e:
        print(f"[analytics][FATAL] {e}")
        return 2

    consumer = Consumer(conf)
    print(
        f"[analytics] topic={topic} group={group_id} window={WINDOW_SEC}s proto={proto} bootstrap={conf['bootstrap.servers']}"
    )
    consumer.subscribe([topic])

    wq: "queue.Queue[WindowPayload]" = queue.Queue(maxsize=50)
    writer = FirestoreWriter(db, wq)
    writer.start()

    per_site_counts: Dict[int, Counter] = {}
    per_site_amount: Dict[int, int] = {}

    last_flush = time.time()

    def flush_now():
        nonlocal last_flush, per_site_counts, per_site_amount

        dt = utc_now()
        window_start = window_bucket_ts(dt, WINDOW_SEC)

        snapshot_counts: Dict[int, Dict[str, int]] = {}
        snapshot_amount: Dict[int, int] = {}

        for site_id, ctr in per_site_counts.items():
            snapshot_counts[int(site_id)] = {k: int(v) for k, v in ctr.items()}
        for site_id, amt in per_site_amount.items():
            snapshot_amount[int(site_id)] = int(amt)

        if PRINT_LOCAL_STATS:
            for site_id, counts in snapshot_counts.items():
                amt = snapshot_amount.get(site_id, 0)
                print("\n=== REAL-TIME ANALYTICS (last window) ===")
                print("site_id:", site_id)
                print("Event counts:", counts)
                print("Total amount:", amt)
                print("========================================\n")

        payload = WindowPayload(
            created_at=dt,
            window_start=window_start,
            window_sec=WINDOW_SEC,
            per_site_counts=snapshot_counts,
            per_site_amount=snapshot_amount,
        )

        try:
            wq.put(payload, timeout=2)
        except queue.Full:
            print("[FIRESTORE][writer] queue is full, dropping this window payload")

        per_site_counts = {}
        per_site_amount = {}
        last_flush = time.time()

    try:
        while True:
            msg = consumer.poll(1.0)

            now = time.time()
            if now - last_flush >= WINDOW_SEC:
                flush_now()

            if msg is None:
                continue

            if msg.error():
                if msg.error().code() in (KafkaError.UNKNOWN_TOPIC_OR_PART, KafkaError._UNKNOWN_TOPIC):
                    time.sleep(1)
                    continue
                if msg.error().code() == KafkaError._MAX_POLL_EXCEEDED:
                    print(f"[ERROR] {msg.error()}")
                    continue
                print(f"[ERROR] {msg.error()}")
                continue

            try:
                event = json.loads(msg.value().decode("utf-8"))
            except Exception as e:
                print(f"[WARN] Invalid JSON: {e}")
                continue

            site_id = get_site_id(event)
            event_type = str(event.get("event_type", "unknown"))
            amount = int(event.get("amount", 0) or 0)

            if site_id not in per_site_counts:
                per_site_counts[site_id] = Counter()
                per_site_amount[site_id] = 0

            per_site_counts[site_id][event_type] += 1
            per_site_amount[site_id] += amount

            if STORE_RAW_EVENTS:
                kafka_meta = {
                    "topic": msg.topic(),
                    "partition": msg.partition(),
                    "offset": msg.offset(),
                    "timestamp": msg.timestamp()[1],
                    "key": (msg.key().decode("utf-8") if msg.key() else None),
                }
                try:
                    write_raw_event(db, event, kafka_meta)
                except Exception as e:
                    print(f"[FIRESTORE][raw_events] failed: {type(e).__name__}: {e}")

    except KeyboardInterrupt:
        return 0
    finally:
        try:
            consumer.close()
        except Exception:
            pass


if __name__ == "__main__":
    raise SystemExit(main())
