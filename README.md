
# Site Management – Kafka Analytics

A small distributed system for **real-time event analytics** using **Apache Kafka** and **Firebase Firestore**.

It follows a simple **producer–consumer** architecture:

- **Simulator service** produces site-management events to Kafka
- **Analytics service** consumes them and writes aggregates to Firestore

---

## Components

- **Kafka Cluster (KRaft)**: `kafka-1`, `kafka-2`, `kafka-3`
- **Optional broker**: `kafka-4` for broker-scaling demo
- **Simulator Service**: producer
- **Analytics Service**: consumer
- **Kafka UI**: cluster inspection

---

## Firestore Output

The analytics service writes the following collections:

- `agg_lifetime`
- `agg_daily`
- `agg_window`

---

## Firebase Setup

You must provide your own Firebase Admin key:

```bash
analytics-service/serviceAccountKey.json
````

---

## Prerequisites

Before running the project, make sure you have:

* **Docker**
* **Docker Compose**
* **GNU Make**
* A **Firebase project** with **Firestore enabled**
* A **Firebase Admin service account key** in JSON format

---

## Startup

Start the full environment:

```bash
make compose-up
```

Show running containers:

```bash
make ps
```

View service logs:

```bash
make logs-simulator
make logs-analytics
```

---

## Scalability

Scale analytics consumers to 2:

```bash
make scale-analytics-2
```

Scale back to 1:

```bash
make scale-analytics-1
```

Using Kafka UI, you can observe:

* consumer group members
* partition reassignment
* rebalance behavior

---

## Security

### Admin success case

```bash
make security-admin
```

### Wrong credentials

```bash
make security-wrong
```

### Intruder / authorization failure

```bash
make security-intruder
```

---

## SSL Certificate Demo Commands

### Producer with valid certificate

```bash
make attacker-producer-valid-cert-demo
```

### Producer with invalid certificate

```bash
make attacker-producer-invalid-cert-demo
```

### Consumer with valid certificate

```bash
make attacker-consumer-valid-cert-demo
```

### Consumer with invalid certificate

```bash
make attacker-consumer-invalid-cert-demo
```

---

## SASL/SCRAM Credential Demo Commands

### Producer with valid credentials

```bash
make attacker-producer-valid-creds-demo
```

### Producer with wrong credentials

```bash
make attacker-producer-wrong-creds-demo
```

### Consumer with valid credentials

```bash
make attacker-consumer-valid-creds-demo
```

### Consumer with wrong credentials

```bash
make attacker-consumer-wrong-creds-demo
```

---

## Broker-4 / Inter-Broker Permission Demo

Start broker-4:

```bash
make broker4-up
make broker4-check
```

After updating `KAFKA_SUPER_USERS` to include `User:kafka-4`, run:

```bash
make broker4-fix-kafka1
make broker4-fix-kafka3
make broker4-fix-kafka4
make broker4-fix
make broker4-verify
make broker4-topic
make broker4-check
```

---

## Cleanup

Stop attacker/demo containers:

```bash
make attacker-down
```

Re-copy security property files if needed:

```bash
make props-copy
```

---

## Tech Stack

* **Apache Kafka (KRaft)**
* **Python**
* **Firebase Firestore**
* **Docker Compose**
* **Kafka UI**

```

İstersen bunu daha profesyonel ve kısa bir GitHub README formatına da çevirebilirim.
```
