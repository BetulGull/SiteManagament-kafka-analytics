#!/usr/bin/env bash
set -euo pipefail

BOOTSTRAP_SSL="${BOOTSTRAP_SSL:-kafka-1:9093}"
TOPIC="${TOPIC:-events}"
PARTITIONS="${PARTITIONS:-6}"
REPLICATION_FACTOR="${REPLICATION_FACTOR:-3}"
MIN_ISR="${MIN_ISR:-2}"
CLIENT_PROPS="${CLIENT_PROPS:-/sec/clients/producer/client-ssl.properties}"

if [[ ! -f "$CLIENT_PROPS" ]]; then
  echo "FATAL: client properties not found: $CLIENT_PROPS" >&2
  exit 2
fi

echo "[kafka-init] Waiting for Kafka over SSL: $BOOTSTRAP_SSL"
for i in {1..60}; do
  if kafka-topics --bootstrap-server "$BOOTSTRAP_SSL" --command-config "$CLIENT_PROPS" --list >/dev/null 2>&1; then
    echo "[kafka-init] SSL reachable."
    break
  fi
  sleep 2
  if [[ "$i" -eq 60 ]]; then
    echo "FATAL: Kafka not reachable over SSL after retries." >&2
    exit 3
  fi
done

echo "[kafka-init] Creating topic: $TOPIC (p=$PARTITIONS, rf=$REPLICATION_FACTOR, minISR=$MIN_ISR)"
kafka-topics \
  --bootstrap-server "$BOOTSTRAP_SSL" \
  --command-config "$CLIENT_PROPS" \
  --create --if-not-exists \
  --topic "$TOPIC" \
  --partitions "$PARTITIONS" \
  --replication-factor "$REPLICATION_FACTOR" \
  --config "min.insync.replicas=$MIN_ISR"

echo "[kafka-init] Verifying topic exists..."
DESC="$(kafka-topics --bootstrap-server "$BOOTSTRAP_SSL" --command-config "$CLIENT_PROPS" --describe --topic "$TOPIC")"
echo "$DESC"

echo "$DESC" | grep -F "Topic: $TOPIC" >/dev/null
echo "$DESC" | grep -E "PartitionCount:[[:space:]]*$PARTITIONS|PartitionCount:$PARTITIONS" >/dev/null

echo "[kafka-init] OK."
exit 0
