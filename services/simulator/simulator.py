import json, os, random, time
from datetime import datetime, timezone
from confluent_kafka import Producer

BOOTSTRAP = os.getenv("KAFKA_BOOTSTRAP", "kafka-1:19092")
TOPIC = os.getenv("TOPIC", "events")
RATE = float(os.getenv("RATE_PER_SEC", "5"))
BUILDINGS = os.getenv("BUILDINGS", "A,B,C").split(",")

EVENT_TYPES = [
    "gate_entry",
    "gate_exit",
    "elevator_fault",
    "maintenance_request",
    "payment_received",
    "security_alert",
    "cleaning_done",
]

COUNTRIES = ["TR", "IT", "DE", "FR"]
MAINT_CATEGORIES = ["elevator", "plumbing", "electric", "garden", "cleaning"]
SEVERITY = ["low", "medium", "high"]

def now_iso():
    return datetime.now(timezone.utc).isoformat()

def make_event(i: int) -> dict:
    b = random.choice(BUILDINGS)
    et = random.choice(EVENT_TYPES)
    base = {
        "event_id": f"evt-{int(time.time()*1000)}-{i}",
        "ts": now_iso(),
        "building": b,
        "country": random.choice(COUNTRIES),
        "event_type": et,
    }
    if et in ("gate_entry", "gate_exit"):
        base["resident_id"] = random.randint(1, 500)
    elif et == "elevator_fault":
        base["elevator_id"] = f"{b}-E{random.randint(1,4)}"
        base["severity"] = random.choice(SEVERITY)
    elif et == "maintenance_request":
        base["category"] = random.choice(MAINT_CATEGORIES)
        base["priority"] = random.choice(SEVERITY)
    elif et == "payment_received":
        base["resident_id"] = random.randint(1, 500)
        base["amount"] = round(random.uniform(200, 2500), 2)
        base["method"] = random.choice(["card", "bank_transfer", "cash"])
    elif et == "security_alert":
        base["severity"] = random.choice(SEVERITY)
        base["zone"] = random.choice(["gate", "parking", "lobby", "garden"])
    elif et == "cleaning_done":
        base["area"] = random.choice(["lobby", "stairs", "elevator", "garden"])
    return base

def main():
    p = Producer({"bootstrap.servers": BOOTSTRAP})
    i = 0
    sleep_s = 1.0 / max(RATE, 0.1)

    print(f"[simulator] bootstrap={BOOTSTRAP} topic={TOPIC} rate={RATE}/s buildings={BUILDINGS}")

    while True:
        ev = make_event(i)
        key = ev["building"].encode()
        val = json.dumps(ev).encode()

        p.produce(TOPIC, key=key, value=val)
        p.poll(0)

        i += 1
        time.sleep(sleep_s)

if __name__ == "__main__":
    main()
