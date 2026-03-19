import json
import os
import random
import time
from datetime import datetime, timezone

from confluent_kafka import Producer

from shared.kafka_config import KafkaConfigError, build_kafka_conf


EVENT_TYPES = [
    "aidat_paid",
    "maintenance_requested",
    "maintenance_completed",
    "security_alert",
    "announcement_published",
]


def _env(name: str, default: str) -> str:
    v = os.getenv(name, default)
    return v.strip() if v else default


def delivery_report(err, msg) -> None:
    if err is not None:
        print(f"[DELIVERY FAILED] {err}")
        return
    print(f"[DELIVERED] topic={msg.topic()} partition={msg.partition()} offset={msg.offset()}")


def main() -> int:
    topic = _env("TOPIC", "events")
    interval = float(_env("PRODUCE_INTERVAL_SEC", "1"))
    proto = _env("KAFKA_SECURITY_PROTOCOL", "ssl").lower()

    base_conf = {
        "acks": "all",
        "enable.idempotence": True,
        "retries": 10,
        "linger.ms": 50,
        "request.timeout.ms": 30000,
        "message.timeout.ms": 30000,
    }

    try:
        producer_conf = build_kafka_conf(base=base_conf)
    except KafkaConfigError as e:
        print(f"[simulator][FATAL] {e}")
        return 2

    producer = Producer(producer_conf)
    print(
        f"[simulator] topic={topic} interval={interval}s proto={proto} "
        f"bootstrap={producer_conf['bootstrap.servers']}"
    )

    while True:
        event = {
            "event_type": random.choice(EVENT_TYPES),
            "site_id": random.randint(1, 3),
            "building_id": random.randint(1, 5),
            "flat_no": random.randint(1, 40),
            "amount": random.randint(200, 1500),
            "priority": random.choice(["low", "medium", "high"]),
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }

        producer.produce(topic=topic, value=json.dumps(event), on_delivery=delivery_report)
        producer.poll(0)
        time.sleep(interval)


if __name__ == "__main__":
    raise SystemExit(main())
