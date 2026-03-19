import os
from confluent_kafka import Consumer

bootstrap = os.getenv("KAFKA_BOOTSTRAP", "kafka-1:9092")
topic = os.getenv("TOPIC", "events")
group_id = os.getenv("GROUP_ID", "site-analytics")

c = Consumer({
    "bootstrap.servers": bootstrap,
    "group.id": group_id,
    "auto.offset.reset": "earliest",
    "enable.auto.commit": True,
})

c.subscribe([topic])
print("[analytics] subscribed")

while True:
    msg = c.poll(1.0)
    if msg is None:
        continue
    if msg.error():
        print("[analytics] error:", msg.error())
        continue
    print(f"[analytics] {msg.topic()}[{msg.partition()}]@{msg.offset()} key={msg.key()} value={msg.value()}")
