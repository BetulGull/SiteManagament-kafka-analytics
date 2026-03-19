import json
import os
import time

import psycopg2
from confluent_kafka import Producer

DB_HOST = os.getenv("DB_HOST", "postgres")
DB_PORT = int(os.getenv("DB_PORT", "5432"))
DB_NAME = os.getenv("DB_NAME", "ordersdb")
DB_USER = os.getenv("DB_USER", "ordersuser")
DB_PASSWORD = os.getenv("DB_PASSWORD", "orderspass")

KAFKA_BOOTSTRAP = os.getenv("KAFKA_BOOTSTRAP", "kafka-1:19092")
ORDERS_TOPIC = os.getenv("ORDERS_TOPIC", "orders")

POLL_SECONDS = float(os.getenv("POLL_SECONDS", "1.0"))

def get_conn():
    return psycopg2.connect(
        host=DB_HOST, port=DB_PORT, dbname=DB_NAME, user=DB_USER, password=DB_PASSWORD
    )

def delivery_report(err, msg):
    if err is not None:
        print(f"DELIVERY FAILED: {err}")
    else:
        print(f"DELIVERED to {msg.topic()} [{msg.partition()}] offset {msg.offset()}")

def main():
    producer = Producer({"bootstrap.servers": KAFKA_BOOTSTRAP})

    while True:
        conn = None
        try:
            conn = get_conn()
            conn.autocommit = False
            cur = conn.cursor()

            # Lock one unpublished event to avoid double-publish if multiple workers exist
            cur.execute("""
                SELECT id, event_type, payload
                FROM outbox
                WHERE published_at IS NULL
                ORDER BY id
                FOR UPDATE SKIP LOCKED
                LIMIT 1;
            """)
            row = cur.fetchone()

            if not row:
                conn.commit()
                cur.close()
                conn.close()
                time.sleep(POLL_SECONDS)
                continue

            outbox_id, event_type, payload = row
            payload_dict = payload if isinstance(payload, dict) else json.loads(payload)

            producer.produce(
                topic=ORDERS_TOPIC,
                key=str(payload_dict.get("order_id", outbox_id)),
                value=json.dumps({"event_type": event_type, "data": payload_dict}),
                callback=delivery_report,
            )
            producer.flush(10)

            cur.execute(
                "UPDATE outbox SET published_at = NOW() WHERE id = %s;",
                (outbox_id,),
            )

            conn.commit()
            cur.close()
            conn.close()

        except Exception as e:
            print(f"WORKER ERROR: {e}")
            try:
                if conn:
                    conn.rollback()
            except Exception:
                pass
            time.sleep(2.0)

if __name__ == "__main__":
    main()
