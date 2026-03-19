import os, time
from confluent_kafka import Producer

bootstrap = os.getenv("KAFKA_BOOTSTRAP", "kafka-1:9092")
topic = os.getenv("TOPIC", "events")

p = Producer({"bootstrap.servers": bootstrap})

i = 0
while True:
    p.produce(topic, key="health", value=f"simulator_alive_{i}")
    p.poll(0)
    i += 1
    print(f"[simulator] produced {i}")
    time.sleep(1)
