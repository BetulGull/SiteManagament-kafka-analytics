
# Site Management – Kafka Analytics 

A small distributed system for **real-time event analytics** using **Apache Kafka** and **Firebase Firestore**.  
It follows a classic **producer–consumer** microservices architecture: a simulator produces events to Kafka, and an analytics service consumes them and stores aggregated results in Firestore.

---

## Project Overview

This project simulates “site management / apartment” style events (e.g., announcements, maintenance, payments, security alerts), streams them through a **Kafka cluster**, and computes simple aggregates in near real time.

**Main goals**
- Event-driven architecture with Kafka
- High availability via broker replication
- Security via TLS + SASL (SCRAM)
- Scalability via horizontal scaling (brokers + microservice replicas)
- Persistence of analytics in Firestore

---

## Architecture

**Components**
1. **Kafka Cluster (KRaft mode)**  
   - Brokers: `kafka-1`, `kafka-2`, `kafka-3`  
   - Optional: `kafka-4` to demonstrate scaling at broker level
2. **Simulator Service (Producer)**  
   - Generates mock events continuously and publishes them to Kafka (`events` topic)
3. **Analytics Service (Consumer)**  
   - Consumes events from Kafka
   - Prints windowed stats to terminal
   - Writes aggregates to **Firebase Firestore**

---

## Data & Firestore

The analytics service writes:
- `agg_lifetime` (lifetime totals per site)
- `agg_daily` (daily totals per site)
- `agg_window` (window snapshots per site, e.g., every 10s)

> Your Firebase Admin key file is **NOT committed**.  
> You must provide your own Firestore project and service account key.

---

## Prerequisites

- Docker + Docker Compose
- GNU Make (or compatible `make`)
- A Firebase project with Firestore enabled
- Firebase Admin service account key JSON

---

## Setup

### 1) Place the Firebase key

Put your key here:

```bash
analytics-service/serviceAccountKey.json
````

This file is ignored by git (`.gitignore`) and is mounted read-only into the analytics container.

### 2) Start the stack

Build & start Kafka (3 brokers) + services:

```bash
make up
```

If you also want to start `kafka-4` (broker scaling demo):

```bash
make up-k4
```

---

## Kafka Topic

Create the `events` topic (recommended defaults used in the project):

```bash
make topic-create
```

Check topic status:

```bash
make topic-describe
```

---

## Useful Commands

### View containers

```bash
make ps
```

### Follow logs

All logs:

```bash
make logs
```

Kafka only:

```bash
make logs-kafka
```

Analytics only:

```bash
make logs-analytics
```

Simulator only:

```bash
make logs-simulator
```

---

## Scalability Demo

### A) Microservice scaling (consumer replication)

Scale analytics consumers to 2 instances (Kafka group rebalance will happen):

```bash
make scale-analytics-2
```

Scale back to 1:

```bash
make scale-analytics-1
```

How to “see” the scaling:

* `make ps` will show 2 analytics containers when scaled up
* Kafka group assignment can be checked with:

```bash
make cg-describe
```

You should see partitions split between two consumer IDs when `scale=2`.

### B) Producer scaling (simulator replication)

Scale simulator to 2 producers (more load / higher event rate):

```bash
make scale-simulator-2
```

Scale back:

```bash
make scale-simulator-1
```

---

## Security (TLS + SASL + ACL)

Kafka is configured with:

* TLS encryption for broker–client traffic
* SASL/SCRAM-SHA-256 authentication for services
* ACL-based authorization (deny by default)

### Quick negative auth test (wrong credentials)

This should fail with `SaslAuthenticationException`:

```bash
make auth-test-wrong
```

---

## Security “Attacker” Tests (Optional)

The repo includes attacker services to demonstrate security failures (e.g., invalid certificate / invalid CA).
Start them with:

```bash
make attacker-up
```

Stop them with:

```bash
make attacker-down
```

You can observe expected failures via:

```bash
docker compose -f docker-compose-attacker.yml logs -f --tail=200
```

---

## Stopping the System (to avoid Firestore filling up)

Stop everything (keep volumes/data):

```bash
make down
```

Stop everything and remove volumes (full reset):

```bash
make down-v
```

> Tip: For demos, always stop the simulator and analytics when done to avoid accumulating Firestore writes.

---

## Tech Stack

* **Apache Kafka (KRaft)** – event streaming / message broker
* **Python** – microservices implementation
* **Firebase Firestore** – persistent analytics storage
* **Docker Compose** – local orchestration


