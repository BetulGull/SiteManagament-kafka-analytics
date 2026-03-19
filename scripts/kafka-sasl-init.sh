#!/usr/bin/env bash
set -euo pipefail

ZK="${ZK:-zookeeper:2181}"

APP_USER="${KAFKA_APP_USER:-app}"
APP_PASS="${KAFKA_APP_PASSWORD:-app-secret-123}"

ADMIN_USER="${KAFKA_ADMIN_USER:-admin}"
ADMIN_PASS="${KAFKA_ADMIN_PASSWORD:-admin-secret-123}"

echo "[kafka-sasl-init] Creating SCRAM users in Zookeeper..."
kafka-configs --zookeeper "$ZK" --alter \
  --add-config "SCRAM-SHA-256=[password=${ADMIN_PASS}]" \
  --entity-type users --entity-name "$ADMIN_USER"

kafka-configs --zookeeper "$ZK" --alter \
  --add-config "SCRAM-SHA-256=[password=${APP_PASS}]" \
  --entity-type users --entity-name "$APP_USER"

echo "[kafka-sasl-init] Done."
