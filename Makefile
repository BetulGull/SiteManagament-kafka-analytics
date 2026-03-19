# Makefile - SiteManagement Kafka Analytics
# Usage examples:
#   make up
#   make logs
#   make scale-analytics-2
#   make attacker-up
#   make down-v

DC := docker compose

# Kafka cluster (KRaft) - base stack
BASE   := -f docker-compose.yml -f docker-compose-kafka-kraft.yml

# Microservices (SASL_SSL) - simulator + analytics
SERV   := -f docker-compose-services-sasl.yml

# Optional: add 4th broker (kafka-4)
K4     := -f docker-compose-kafka4.yml

# Optional: analytics scaling overrides (your file that fixed env for scale)
SCALEA := -f docker-compose-analytics-scale.yml

# Security/attacker tests
ATTACK := -f docker-compose-attacker.yml --profile attack

.DEFAULT_GOAL := help

help:
	@echo ""
	@echo "Targets:"
	@echo "  make up                  -> Start Kafka (kafka-1..3) + services (simulator + analytics)"
	@echo "  make up-k4               -> Start Kafka + services + kafka-4 (4th broker)"
	@echo "  make down                -> Stop stack (keeps volumes)"
	@echo "  make down-v              -> Stop stack and remove volumes"
	@echo "  make ps                  -> Show running containers"
	@echo "  make logs                -> Follow logs for all services"
	@echo "  make logs-kafka          -> Follow logs for kafka brokers"
	@echo "  make logs-analytics       -> Follow logs for analytics-service"
	@echo "  make logs-simulator       -> Follow logs for simulator-service"
	@echo ""
	@echo "Scaling:"
	@echo "  make scale-analytics-2    -> Run 2 analytics consumers (group rebalance will happen)"
	@echo "  make scale-analytics-1    -> Back to 1 analytics consumer"
	@echo "  make scale-simulator-2    -> Run 2 simulators (more load)"
	@echo "  make scale-simulator-1    -> Back to 1 simulator"
	@echo ""
	@echo "Security tests:"
	@echo "  make attacker-up          -> Run attacker services (invalid cert / invalid CA)"
	@echo "  make attacker-down        -> Stop attacker services"
	@echo "  make auth-test-wrong      -> CLI test: wrong SASL credentials (should FAIL)"
	@echo ""
	@echo "Kafka topic helpers:"
	@echo "  make topic-create         -> Create 'events' topic (6 partitions, RF=3, minISR=2)"
	@echo "  make topic-describe       -> Describe 'events' topic"
	@echo "  make cg-describe          -> Describe consumer group 'analytics-group' (SASL_SSL admin config)"
	@echo ""

# ------------------------------------------------------------
# Stack lifecycle
# ------------------------------------------------------------

up:
	$(DC) $(BASE) $(SERV) up -d --build

up-k4:
	$(DC) $(BASE) $(SERV) $(K4) up -d --build

down:
	$(DC) $(BASE) $(SERV) $(K4) $(SCALEA) down --remove-orphans || true

down-v:
	$(DC) $(BASE) $(SERV) $(K4) $(SCALEA) down --volumes --remove-orphans || true

ps:
	$(DC) $(BASE) $(SERV) $(K4) $(SCALEA) ps

logs:
	$(DC) $(BASE) $(SERV) $(K4) $(SCALEA) logs -f --tail=200

logs-kafka:
	$(DC) $(BASE) logs -f --tail=200 kafka-1 kafka-2 kafka-3 || true

logs-analytics:
	$(DC) $(BASE) $(SERV) $(SCALEA) logs -f --tail=200 analytics-service || true

logs-simulator:
	$(DC) $(BASE) $(SERV) logs -f --tail=200 simulator-service || true

restart-analytics:
	$(DC) $(BASE) $(SERV) $(SCALEA) restart analytics-service

restart-simulator:
	$(DC) $(BASE) $(SERV) restart simulator-service

# ------------------------------------------------------------
# Scaling (microservices)
# Notes:
# - analytics-service scaling uses docker-compose-analytics-scale.yml
# - simulator scaling is possible as long as docker-compose-services-sasl.yml
#   does NOT hardcode container_name for simulator-service.
# ------------------------------------------------------------

scale-analytics-2:
	$(DC) $(BASE) $(SERV) $(SCALEA) up -d --no-recreate --scale analytics-service=2 analytics-service

scale-analytics-1:
	$(DC) $(BASE) $(SERV) $(SCALEA) up -d --no-recreate --scale analytics-service=1 analytics-service

scale-simulator-2:
	$(DC) $(BASE) $(SERV) up -d --no-recreate --scale simulator-service=2 simulator-service

scale-simulator-1:
	$(DC) $(BASE) $(SERV) up -d --no-recreate --scale simulator-service=1 simulator-service

# ------------------------------------------------------------
# Attacker/Security tests (from docker-compose-attacker.yml)
# Your attacker compose uses "profiles: [attack]" on services,
# so we run with --profile attack.
# ------------------------------------------------------------

attacker-up:
	$(DC) $(BASE) $(ATTACK) up -d --build

attacker-down:
	$(DC) $(BASE) $(ATTACK) down --remove-orphans || true

# ------------------------------------------------------------
# CLI negative test: wrong SASL credentials (should fail)
# Runs from kafka-1 container and tries SASL_SSL admin request with wrong creds
# ------------------------------------------------------------

auth-test-wrong:
	docker exec -it kafka-1 bash -lc '\
cat > /tmp/client-sasl-wrong.properties <<EOF\n\
security.protocol=SASL_SSL\n\
sasl.mechanism=SCRAM-SHA-256\n\
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required username="intruder" password="wrong";\n\
ssl.endpoint.identification.algorithm=\n\
ssl.truststore.location=/etc/kafka/secrets/truststore.p12\n\
ssl.truststore.password=changeit\n\
ssl.truststore.type=PKCS12\n\
EOF\n\
kafka-topics --bootstrap-server kafka-1:9094 --command-config /tmp/client-sasl-wrong.properties --list'

# ------------------------------------------------------------
# Topic / group helpers (PLAINTEXT admin on 9092)
# ------------------------------------------------------------

topic-create:
	docker exec -it kafka-1 bash -lc '\
kafka-topics --bootstrap-server kafka-1:9092 \
  --create --topic events \
  --partitions 6 \
  --replication-factor 3 \
  --config min.insync.replicas=2 || true'

topic-describe:
	docker exec -it kafka-1 bash -lc '\
kafka-topics --bootstrap-server kafka-1:9092 --describe --topic events | sed -n "1,80p"'

cg-describe:
	docker exec -it kafka-1 bash -lc '\
kafka-consumer-groups --bootstrap-server kafka-1:9094 \
  --command-config /tmp/client-sasl-admin.properties \
  --describe --group analytics-group || true'

