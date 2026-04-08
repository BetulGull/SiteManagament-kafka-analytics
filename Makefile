SHELL := /bin/bash
.DEFAULT_GOAL := help

PROJECT ?= kafka-project
DC := docker compose

BASE  := -f docker-compose-kafka-kraft.yml
SERV  := -f docker-compose-services-sasl.yml
SCALE := -f docker-compose-analytics-scale.yml
UI    := -f docker-compose-kafka-ui.yml
K4    := -f docker-compose-kafka4.yml

BROKER      := kafka-1
TOPIC       := events
TOPIC_SCALE := events-scale-demo-2
GROUP       := analytics-group
NETWORK     := $(PROJECT)_default

SIMULATOR_IMAGE := $(PROJECT)-simulator-service:latest
ANALYTICS_IMAGE := $(PROJECT)-analytics-service:latest

ROOT := $(CURDIR)

ATTACKER_PRODUCER_INVALID_CERT := attacker-producer-invalid-cert
ATTACKER_PRODUCER_WRONG_CREDS  := attacker-producer-wrong-creds
ATTACKER_CONSUMER_INVALID_CERT := attacker-consumer-invalid-cert
ATTACKER_CONSUMER_WRONG_CREDS  := attacker-consumer-wrong-creds
ATTACKER_PRODUCER_VALID_CERT   := attacker-producer-valid-cert 
ATTACKER_CONSUMER_VALID_CERT   := attacker-consumer-valid-cert
ATTACKER_PRODUCER_VALID_CREDS  := attacker-producer-valid-creds
ATTACKER_CONSUMER_VALID_CREDS  := attacker-consumer-valid-creds
 
.PHONY: help
help:
	@echo ""
	@echo "Main:"
	@echo "  make doctor                               -> Check required local files"
	@echo "  make demo-up                              -> Start validated demo stack"
	@echo "  make demo-down                            -> Stop stack"
	@echo "  make demo-down-v                          -> Stop stack and remove volumes"
	@echo "  make compose-up                           -> Alias of demo-up"
	@echo "  make compose-down                         -> Alias of demo-down-v"
	@echo "  make ps                                   -> Show running containers"
	@echo ""
	@echo "Cluster:"
	@echo "  make kafka-up                             -> Start 3-broker KRaft cluster"
	@echo "  make kafka-down                           -> Stop 3-broker KRaft cluster"
	@echo "  make ui-up                                -> Start Kafka UI"
	@echo "  make ui-down                              -> Stop Kafka UI"
	@echo "  make users-init                           -> Create SCRAM users"
	@echo "  make topic-init                           -> Create events topic"
	@echo "  make acls-init                            -> Create ACLs"
	@echo "  make props-copy                           -> Copy SASL client props into kafka-1"
	@echo ""
	@echo "Services:"
	@echo "  make services-build                       -> Build simulator + analytics images"
	@echo "  make services-up                          -> Start simulator + analytics"
	@echo "  make services-down                        -> Stop simulator + analytics"
	@echo "  make logs-simulator                       -> Show simulator logs"
	@echo "  make logs-analytics                       -> Show analytics logs"
	@echo "  make logs-kafka                           -> Show broker logs"
	@echo "  make logs-all                             -> Show all logs"
	@echo ""
	@echo "Fault tolerance / scaling:"
	@echo "  make describe-events                      -> Describe events topic"
	@echo "  make broker3-stop                         -> Stop kafka-3"
	@echo "  make broker3-start                        -> Start kafka-3"
	@echo "  make group-describe                       -> Describe analytics consumer group"
	@echo "  make scale-analytics-2                    -> Scale analytics to 2"
	@echo "  make scale-analytics-1                    -> Scale analytics back to 1"
	@echo "  make broker4-up                           -> Start kafka-4 cleanly"
	@echo "  make broker4-down                         -> Remove kafka-4"
	@echo "  make broker4-recreate                     -> Recreate kafka-4 from scratch"
	@echo "  make broker4-check                        -> Check kafka-4 logs + API reachability"
	@echo "  make broker4-topic                        -> Create/describe broker scaling demo topic"
	@echo ""
	@echo "Security CLI tests:"
	@echo "  make security-admin                       -> Valid SASL admin access"
	@echo "  make security-wrong                       -> Wrong SASL password"
	@echo "  make security-intruder                    -> Authenticated but unauthorized consumer"
	@echo "  make security-demo                        -> Run all three security CLI tests + attackers"
	@echo ""
	@echo "Attacker scenarios (single):"
	@echo "  make attacker-producer-invalid-cert-up"
	@echo "  make attacker-producer-invalid-cert-status"
	@echo "  make attacker-producer-invalid-cert-logs"
	@echo "  make attacker-producer-invalid-cert-down"
	@echo ""
	@echo "  make attacker-consumer-invalid-cert-up"
	@echo "  make attacker-consumer-invalid-cert-status"
	@echo "  make attacker-consumer-invalid-cert-logs"
	@echo "  make attacker-consumer-invalid-cert-down"
	@echo ""
	@echo "  make attacker-producer-wrong-creds-up"
	@echo "  make attacker-producer-wrong-creds-status"
	@echo "  make attacker-producer-wrong-creds-logs"
	@echo "  make attacker-producer-wrong-creds-down"
	@echo ""
	@echo "  make attacker-consumer-wrong-creds-up"
	@echo "  make attacker-consumer-wrong-creds-status"
	@echo "  make attacker-consumer-wrong-creds-logs"
	@echo "  make attacker-consumer-wrong-creds-down"
	@echo ""
	@echo "Attacker scenarios (all):"
	@echo "  make attacker-up                          -> Start all attacker containers"
	@echo "  make attacker-status                      -> Show all attacker containers"
	@echo "  make attacker-logs                        -> Show all attacker logs"
	@echo "  make attacker-down                        -> Remove all attacker containers"
	@echo ""
	@echo "Demo shortcuts:"
	@echo "  make fault-demo                           -> Broker failure + ISR recovery demo"
	@echo "  make scale-demo                           -> Consumer scaling + broker-4 demo"
	@echo ""
	@echo "Cleanup:"
	@echo "  make clean                                -> Remove optional extras"
	@echo "  make all-down                             -> Stop attackers + demo stack"
	@echo "  make prune                                -> docker system prune --volumes -f"
	@echo "  make docker-clean                         -> Alias of prune"
	@echo ""

.PHONY: doctor
doctor:
	@test -f analytics-service/serviceAccountKey.json && echo "OK  analytics-service/serviceAccountKey.json" || (echo "MISSING analytics-service/serviceAccountKey.json" && exit 1)
	@test -f security/ca/ca.crt && echo "OK  security/ca/ca.crt" || (echo "MISSING security/ca/ca.crt" && exit 1)
	@test -f scripts/client-sasl-admin.properties && echo "OK  scripts/client-sasl-admin.properties" || (echo "MISSING scripts/client-sasl-admin.properties" && exit 1)
	@test -f scripts/client-sasl-wrong.properties && echo "OK  scripts/client-sasl-wrong.properties" || (echo "MISSING scripts/client-sasl-wrong.properties" && exit 1)
	@test -f scripts/client-sasl-intruder.properties && echo "OK  scripts/client-sasl-intruder.properties" || (echo "MISSING scripts/client-sasl-intruder.properties" && exit 1)
	@echo "Doctor check passed."

.PHONY: prepare-demo
prepare-demo:
	-$(MAKE) attacker-down
	-docker rm -f kafka-4 2>/dev/null || true
	-docker rm -f kafka-ui 2>/dev/null || true
	-docker rm -f $(PROJECT)-analytics-service-2 2>/dev/null || true

.PHONY: demo-up
demo-up: doctor prepare-demo kafka-up ui-up users-init topic-init acls-init props-copy services-up

.PHONY: compose-up
compose-up: demo-up

.PHONY: demo-down
demo-down:
	$(DC) $(BASE) $(SERV) $(SCALE) down --remove-orphans || true
	docker rm -f kafka-ui 2>/dev/null || true
	docker rm -f kafka-4 2>/dev/null || true

.PHONY: demo-down-v
demo-down-v:
	$(DC) $(BASE) $(SERV) $(SCALE) down --volumes --remove-orphans || true
	docker rm -f kafka-ui 2>/dev/null || true
	docker rm -f kafka-4 2>/dev/null || true
	docker volume rm $(PROJECT)_kafka4-data 2>/dev/null || true

.PHONY: compose-down
compose-down: demo-down-v

.PHONY: all-down
all-down: attacker-down demo-down-v

.PHONY: ps
ps:
	@docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

.PHONY: kafka-up
kafka-up:
	$(DC) $(BASE) up -d

.PHONY: kafka-down
kafka-down:
	$(DC) $(BASE) down --remove-orphans

.PHONY: ui-up
ui-up:
	$(DC) $(BASE) $(UI) up -d kafka-ui

.PHONY: ui-down
ui-down:
	docker rm -f kafka-ui 2>/dev/null || true

.PHONY: users-init
users-init:
	docker exec $(BROKER) kafka-configs --bootstrap-server $(BROKER):9092 --alter --add-config 'SCRAM-SHA-256=[iterations=4096,password=producer-secret]' --entity-type users --entity-name producer
	docker exec $(BROKER) kafka-configs --bootstrap-server $(BROKER):9092 --alter --add-config 'SCRAM-SHA-256=[iterations=4096,password=analytics-secret]' --entity-type users --entity-name analytics
	docker exec $(BROKER) kafka-configs --bootstrap-server $(BROKER):9092 --alter --add-config 'SCRAM-SHA-256=[iterations=4096,password=intruder-secret]' --entity-type users --entity-name intruder
	docker exec $(BROKER) kafka-configs --bootstrap-server $(BROKER):9092 --alter --add-config 'SCRAM-SHA-256=[iterations=4096,password=admin-secret]' --entity-type users --entity-name admin
	docker exec $(BROKER) kafka-configs --bootstrap-server $(BROKER):9092 --describe --entity-type users

.PHONY: topic-init
topic-init:
	docker exec $(BROKER) kafka-topics --bootstrap-server $(BROKER):9092 --create --if-not-exists --topic $(TOPIC) --partitions 6 --replication-factor 3 --config min.insync.replicas=2
	docker exec $(BROKER) kafka-topics --bootstrap-server $(BROKER):9092 --describe --topic $(TOPIC)

.PHONY: acls-init
acls-init:
	docker exec $(BROKER) kafka-acls --bootstrap-server $(BROKER):9092 --add --allow-principal User:producer --operation Write --operation Describe --topic $(TOPIC)
	docker exec $(BROKER) kafka-acls --bootstrap-server $(BROKER):9092 --add --allow-principal User:producer --operation IdempotentWrite --cluster
	docker exec $(BROKER) kafka-acls --bootstrap-server $(BROKER):9092 --add --allow-principal User:analytics --operation Read --operation Describe --topic $(TOPIC)
	docker exec $(BROKER) kafka-acls --bootstrap-server $(BROKER):9092 --add --allow-principal User:analytics --operation Read --operation Describe --group $(GROUP)
	docker exec $(BROKER) kafka-acls --bootstrap-server $(BROKER):9092 --list

.PHONY: props-copy
props-copy:
	docker cp scripts/client-sasl-wrong.properties $(BROKER):/tmp/client-sasl-wrong.properties
	docker cp scripts/client-sasl-intruder.properties $(BROKER):/tmp/client-sasl-intruder.properties
	docker cp scripts/client-sasl-admin.properties $(BROKER):/tmp/client-sasl-admin.properties

.PHONY: services-build
services-build:
	$(DC) $(BASE) $(SERV) build simulator-service analytics-service

.PHONY: services-up
services-up:
	$(DC) $(BASE) $(SERV) up -d --build simulator-service analytics-service

.PHONY: services-down
services-down:
	$(DC) $(BASE) $(SERV) stop simulator-service analytics-service || true
	docker rm -f $(PROJECT)-simulator-service-1 2>/dev/null || true
	docker rm -f $(PROJECT)-analytics-service-1 2>/dev/null || true
	docker rm -f $(PROJECT)-analytics-service-2 2>/dev/null || true

.PHONY: logs-simulator
logs-simulator:
	$(DC) $(BASE) $(SERV) logs --tail=40 simulator-service

.PHONY: logs-analytics
logs-analytics:
	$(DC) $(BASE) $(SERV) logs --tail=40 analytics-service

.PHONY: logs-kafka
logs-kafka:
	$(DC) $(BASE) logs --tail=80 kafka-1 kafka-2 kafka-3

.PHONY: logs-all
logs-all:
	$(DC) $(BASE) $(SERV) $(SCALE) logs --tail=120

.PHONY: describe-events
describe-events:
	docker exec $(BROKER) kafka-topics --bootstrap-server $(BROKER):9092 --describe --topic $(TOPIC)

.PHONY: group-describe
group-describe:
	docker exec $(BROKER) kafka-consumer-groups --bootstrap-server $(BROKER):9092 --describe --group $(GROUP)

.PHONY: broker3-stop
broker3-stop:
	docker stop kafka-3

.PHONY: broker3-start
broker3-start:
	docker start kafka-3

.PHONY: scale-analytics-2
scale-analytics-2:
	$(DC) $(BASE) $(SERV) $(SCALE) up -d --no-recreate --scale analytics-service=2 analytics-service

.PHONY: scale-analytics-1
scale-analytics-1:
	$(DC) $(BASE) $(SERV) $(SCALE) up -d --no-recreate --scale analytics-service=1 analytics-service
	sleep 15

.PHONY: broker4-up
broker4-up:
	docker rm -f kafka-4 2>/dev/null || true
	docker volume rm $(PROJECT)_kafka4-data 2>/dev/null || true
	$(DC) $(BASE) $(K4) up -d kafka-4
	sleep 10
	docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

.PHONY: broker4-down
broker4-down:
	docker rm -f kafka-4 2>/dev/null || true
	docker volume rm $(PROJECT)_kafka4-data 2>/dev/null || true

.PHONY: broker4-recreate
broker4-recreate: broker4-down broker4-up

.PHONY: broker4-check
broker4-check:
	docker logs kafka-4 --tail 80
	docker exec $(BROKER) kafka-broker-api-versions --bootstrap-server kafka-4:9092

.PHONY: broker4-fix-kafka1
broker4-fix-kafka1:
	docker compose -f docker-compose-kafka-kraft.yml up -d --force-recreate kafka-1

.PHONY: broker4-fix-kafka3
broker4-fix-kafka3:
	docker compose -f docker-compose-kafka-kraft.yml up -d --force-recreate kafka-3

.PHONY: broker4-fix-kafka4
broker4-fix-kafka4:
	docker compose -f docker-compose-kafka-kraft.yml -f docker-compose-kafka4.yml up -d --force-recreate kafka-4

.PHONY: broker4-fix
broker4-fix: broker4-fix-kafka1 broker4-fix-kafka3 broker4-fix-kafka4

.PHONY: broker4-verify
broker4-verify:
	$(MAKE) broker4-check

.PHONY: broker4-topic
broker4-topic:
	docker exec $(BROKER) kafka-topics --bootstrap-server $(BROKER):9092 --create --if-not-exists --topic $(TOPIC_SCALE) --partitions 8 --replication-factor 3
	docker exec $(BROKER) kafka-topics --bootstrap-server $(BROKER):9092 --describe --topic $(TOPIC_SCALE)

.PHONY: security-admin
security-admin:
	docker exec $(BROKER) kafka-topics --bootstrap-server $(BROKER):9094 --command-config /tmp/client-sasl-admin.properties --describe --topic $(TOPIC)

.PHONY: security-wrong
security-wrong:
	@echo "Expecting SASL authentication failure..."
	-docker exec $(BROKER) kafka-topics --bootstrap-server $(BROKER):9094 --command-config /tmp/client-sasl-wrong.properties --list

.PHONY: security-intruder
security-intruder:
	@echo "Expecting topic authorization failure..."
	-docker exec $(BROKER) kafka-console-consumer --bootstrap-server $(BROKER):9094 --consumer.config /tmp/client-sasl-intruder.properties --topic $(TOPIC) --group intruder-group --timeout-ms 5000

.PHONY: security-demo
security-demo:
	@echo "== Step 1: Valid admin access =="
	$(MAKE) security-admin
	@echo ""
	@echo "== Step 2: Wrong SASL password test =="
	-$(MAKE) security-wrong
	@echo ""
	@echo "== Step 3: Intruder authorization failure =="
	-$(MAKE) security-intruder
	@echo ""
	@echo "== Step 4: Start attacker containers =="
	$(MAKE) attacker-up
	@sleep 5
	@echo ""
	@echo "== Step 5: Show attacker status =="
	$(MAKE) attacker-status
	@echo ""
	@echo "== Step 6: Show attacker logs =="
	$(MAKE) attacker-logs

.PHONY: attacker-producer-invalid-cert-up
attacker-producer-invalid-cert-up:
	docker rm -f $(ATTACKER_PRODUCER_INVALID_CERT) 2>/dev/null || true
	docker run -d --name $(ATTACKER_PRODUCER_INVALID_CERT) --network $(NETWORK) \
		-e BOOTSTRAP_SERVERS="kafka-1:9093,kafka-2:9093,kafka-3:9093" \
		-e TOPIC="$(TOPIC)" \
		-e PRODUCE_INTERVAL_SEC="1" \
		-e KAFKA_SECURITY_PROTOCOL="ssl" \
		-e KAFKA_SSL_CA_LOCATION="/sec/ca.crt" \
		-e KAFKA_SSL_CERT_LOCATION="/sec/client.crt" \
		-e KAFKA_SSL_KEY_LOCATION="/sec/client.key" \
		-e KAFKA_DEBUG="security,broker,protocol" \
		-v $(ROOT)/security/ca/ca.crt:/sec/ca.crt:ro \
		-v $(ROOT)/security/clients/attacker-invalid-cert/client.crt:/sec/client.crt:ro \
		-v $(ROOT)/security/clients/attacker-invalid-cert/client.key:/sec/client.key:ro \
		$(SIMULATOR_IMAGE)

.PHONY: attacker-producer-invalid-cert-status
attacker-producer-invalid-cert-status:
	@docker ps -a --filter "name=$(ATTACKER_PRODUCER_INVALID_CERT)"

.PHONY: attacker-producer-invalid-cert-logs
attacker-producer-invalid-cert-logs:
	@docker logs $(ATTACKER_PRODUCER_INVALID_CERT) --tail 80 2>&1 || true

.PHONY: attacker-producer-invalid-cert-down
attacker-producer-invalid-cert-down:
	docker rm -f $(ATTACKER_PRODUCER_INVALID_CERT) 2>/dev/null || true

.PHONY: attacker-consumer-invalid-cert-up
attacker-consumer-invalid-cert-up:
	docker rm -f $(ATTACKER_CONSUMER_INVALID_CERT) 2>/dev/null || true
	docker run -d --name $(ATTACKER_CONSUMER_INVALID_CERT) --network $(NETWORK) \
		-e BOOTSTRAP_SERVERS="kafka-1:9093,kafka-2:9093,kafka-3:9093" \
		-e TOPIC="$(TOPIC)" \
		-e GROUP_ID="attacker-invalid-cert-group" \
		-e AUTO_OFFSET_RESET="earliest" \
		-e KAFKA_SECURITY_PROTOCOL="ssl" \
		-e KAFKA_SSL_CA_LOCATION="/sec/ca.crt" \
		-e KAFKA_SSL_CERT_LOCATION="/sec/client.crt" \
		-e KAFKA_SSL_KEY_LOCATION="/sec/client.key" \
		-e KAFKA_DEBUG="security,broker,protocol" \
		-v $(ROOT)/security/ca/ca.crt:/sec/ca.crt:ro \
		-v $(ROOT)/security/clients/attacker-invalid-cert/client.crt:/sec/client.crt:ro \
		-v $(ROOT)/security/clients/attacker-invalid-cert/client.key:/sec/client.key:ro \
		$(ANALYTICS_IMAGE)

.PHONY: attacker-consumer-invalid-cert-status
attacker-consumer-invalid-cert-status:
	@docker ps -a --filter "name=$(ATTACKER_CONSUMER_INVALID_CERT)"

.PHONY: attacker-consumer-invalid-cert-logs
attacker-consumer-invalid-cert-logs:
	@docker logs $(ATTACKER_CONSUMER_INVALID_CERT) --tail 80 2>&1 || true

.PHONY: attacker-consumer-invalid-cert-down
attacker-consumer-invalid-cert-down:
	docker rm -f $(ATTACKER_CONSUMER_INVALID_CERT) 2>/dev/null || true

.PHONY: attacker-producer-wrong-creds-up
attacker-producer-wrong-creds-up:
	docker rm -f $(ATTACKER_PRODUCER_WRONG_CREDS) 2>/dev/null || true
	docker run -d --name $(ATTACKER_PRODUCER_WRONG_CREDS) --network $(NETWORK) \
		-e BOOTSTRAP_SERVERS="kafka-1:9094,kafka-2:9094,kafka-3:9094" \
		-e TOPIC="$(TOPIC)" \
		-e PRODUCE_INTERVAL_SEC="1" \
		-e KAFKA_SECURITY_PROTOCOL="sasl_ssl" \
		-e KAFKA_SASL_MECHANISM="SCRAM-SHA-256" \
		-e KAFKA_SASL_USERNAME="producer" \
		-e KAFKA_SASL_PASSWORD="WRONG-PASSWORD" \
		-e KAFKA_SSL_CA_LOCATION="/sec/ca.crt" \
		-e KAFKA_DEBUG="security,broker,protocol" \
		-v $(ROOT)/security/ca/ca.crt:/sec/ca.crt:ro \
		$(SIMULATOR_IMAGE)

.PHONY: attacker-producer-wrong-creds-status
attacker-producer-wrong-creds-status:
	@docker ps -a --filter "name=$(ATTACKER_PRODUCER_WRONG_CREDS)"

.PHONY: attacker-producer-wrong-creds-logs
attacker-producer-wrong-creds-logs:
	@docker logs $(ATTACKER_PRODUCER_WRONG_CREDS) --tail 80 2>&1 || true

.PHONY: attacker-producer-wrong-creds-down
attacker-producer-wrong-creds-down:
	docker rm -f $(ATTACKER_PRODUCER_WRONG_CREDS) 2>/dev/null || true

.PHONY: attacker-consumer-wrong-creds-up
attacker-consumer-wrong-creds-up:
	docker rm -f $(ATTACKER_CONSUMER_WRONG_CREDS) 2>/dev/null || true
	docker run -d --name $(ATTACKER_CONSUMER_WRONG_CREDS) --network $(NETWORK) \
		-e BOOTSTRAP_SERVERS="kafka-1:9094,kafka-2:9094,kafka-3:9094" \
		-e TOPIC="$(TOPIC)" \
		-e GROUP_ID="attacker-wrong-creds-group" \
		-e AUTO_OFFSET_RESET="earliest" \
		-e KAFKA_SECURITY_PROTOCOL="sasl_ssl" \
		-e KAFKA_SASL_MECHANISM="SCRAM-SHA-256" \
		-e KAFKA_SASL_USERNAME="analytics" \
		-e KAFKA_SASL_PASSWORD="WRONG-PASSWORD" \
		-e KAFKA_SSL_CA_LOCATION="/sec/ca.crt" \
		-e KAFKA_DEBUG="security,broker,protocol" \
		-v $(ROOT)/security/ca/ca.crt:/sec/ca.crt:ro \
		$(ANALYTICS_IMAGE)

.PHONY: attacker-consumer-wrong-creds-status
attacker-consumer-wrong-creds-status:
	@docker ps -a --filter "name=$(ATTACKER_CONSUMER_WRONG_CREDS)"

.PHONY: attacker-consumer-wrong-creds-logs
attacker-consumer-wrong-creds-logs:
	@docker logs $(ATTACKER_CONSUMER_WRONG_CREDS) --tail 80 2>&1 || true

.PHONY: attacker-consumer-wrong-creds-down
attacker-consumer-wrong-creds-down:
	docker rm -f $(ATTACKER_CONSUMER_WRONG_CREDS) 2>/dev/null || true

.PHONY: attacker-up
attacker-up: attacker-down services-build attacker-producer-invalid-cert-up attacker-consumer-invalid-cert-up attacker-producer-wrong-creds-up attacker-consumer-wrong-creds-up
	@echo "Attacker containers started."

.PHONY: attacker-down
attacker-down:
	docker rm -f $(ATTACKER_PRODUCER_INVALID_CERT) 2>/dev/null || true
	docker rm -f $(ATTACKER_PRODUCER_WRONG_CREDS) 2>/dev/null || true
	docker rm -f $(ATTACKER_CONSUMER_INVALID_CERT) 2>/dev/null || true
	docker rm -f $(ATTACKER_CONSUMER_WRONG_CREDS) 2>/dev/null || true

.PHONY: attacker-status
attacker-status:
	@docker ps -a \
		--filter "name=$(ATTACKER_PRODUCER_INVALID_CERT)" \
		--filter "name=$(ATTACKER_PRODUCER_WRONG_CREDS)" \
		--filter "name=$(ATTACKER_CONSUMER_INVALID_CERT)" \
		--filter "name=$(ATTACKER_CONSUMER_WRONG_CREDS)"

.PHONY: attacker-logs
attacker-logs:
	@echo "===== $(ATTACKER_PRODUCER_INVALID_CERT) ====="
	@docker logs $(ATTACKER_PRODUCER_INVALID_CERT) --tail 80 2>&1 || true
	@echo "===== $(ATTACKER_PRODUCER_WRONG_CREDS) ====="
	@docker logs $(ATTACKER_PRODUCER_WRONG_CREDS) --tail 80 2>&1 || true
	@echo "===== $(ATTACKER_CONSUMER_INVALID_CERT) ====="
	@docker logs $(ATTACKER_CONSUMER_INVALID_CERT) --tail 80 2>&1 || true
	@echo "===== $(ATTACKER_CONSUMER_WRONG_CREDS) ====="
	@docker logs $(ATTACKER_CONSUMER_WRONG_CREDS) --tail 80 2>&1 || true

.PHONY: attacker-producer-valid-cert-up
attacker-producer-valid-cert-up:
	docker rm -f $(ATTACKER_PRODUCER_VALID_CERT) 2>/dev/null || true
	docker run -d --name $(ATTACKER_PRODUCER_VALID_CERT) --network $(NETWORK) \
		-e BOOTSTRAP_SERVERS="kafka-1:9093,kafka-2:9093,kafka-3:9093" \
		-e TOPIC="$(TOPIC)" \
		-e PRODUCE_INTERVAL_SEC="1" \
		-e KAFKA_SECURITY_PROTOCOL="ssl" \
		-e KAFKA_SSL_CA_LOCATION="/sec/ca.crt" \
		-e KAFKA_SSL_CERT_LOCATION="/sec/client.crt" \
		-e KAFKA_SSL_KEY_LOCATION="/sec/client.key" \
		-e KAFKA_DEBUG="security,broker,protocol" \
		-v $(ROOT)/security/ca/ca.crt:/sec/ca.crt:ro \
		-v $(ROOT)/security/clients/producer/client.crt:/sec/client.crt:ro \
		-v $(ROOT)/security/clients/producer/client.key:/sec/client.key:ro \
		$(SIMULATOR_IMAGE)

.PHONY: attacker-producer-valid-cert-status
attacker-producer-valid-cert-status:
	@docker ps -a --filter "name=$(ATTACKER_PRODUCER_VALID_CERT)"

.PHONY: attacker-producer-valid-cert-logs
attacker-producer-valid-cert-logs:
	@docker logs $(ATTACKER_PRODUCER_VALID_CERT) --tail 120 2>/dev/null || true

.PHONY: attacker-producer-valid-cert-down
attacker-producer-valid-cert-down:
	docker rm -f $(ATTACKER_PRODUCER_VALID_CERT) 2>/dev/null || true

.PHONY: attacker-producer-valid-cert-demo
attacker-producer-valid-cert-demo:
	$(MAKE) attacker-producer-valid-cert-up
	sleep 5
	$(MAKE) attacker-producer-valid-cert-status
	$(MAKE) attacker-producer-valid-cert-logs

.PHONY: attacker-producer-invalid-cert-demo
attacker-producer-invalid-cert-demo:
	$(MAKE) attacker-producer-invalid-cert-up
	sleep 3
	$(MAKE) attacker-producer-invalid-cert-status
	$(MAKE) attacker-producer-invalid-cert-logs

.PHONY: attacker-consumer-valid-cert-up
attacker-consumer-valid-cert-up:
	docker rm -f $(ATTACKER_CONSUMER_VALID_CERT) 2>/dev/null || true
	docker run -d --name $(ATTACKER_CONSUMER_VALID_CERT) --network $(NETWORK) \
		-e BOOTSTRAP_SERVERS="kafka-1:9093,kafka-2:9093,kafka-3:9093" \
		-e TOPIC="$(TOPIC)" \
		-e GROUP_ID="analytics-group" \
		-e AUTO_OFFSET_RESET="latest" \
		-e KAFKA_SECURITY_PROTOCOL="ssl" \
		-e KAFKA_SSL_CA_LOCATION="/sec/ca.crt" \
		-e KAFKA_SSL_CERT_LOCATION="/sec/client.crt" \
		-e KAFKA_SSL_KEY_LOCATION="/sec/client.key" \
		-e KAFKA_DEBUG="security,broker,protocol" \
		-v $(ROOT)/security/ca/ca.crt:/sec/ca.crt:ro \
		-v $(ROOT)/security/clients/analytics/client.crt:/sec/client.crt:ro \
		-v $(ROOT)/security/clients/analytics/client.key:/sec/client.key:ro \
		$(ANALYTICS_IMAGE)

.PHONY: attacker-consumer-valid-cert-status
attacker-consumer-valid-cert-status:
	@docker ps -a --filter "name=$(ATTACKER_CONSUMER_VALID_CERT)"

.PHONY: attacker-consumer-valid-cert-logs
attacker-consumer-valid-cert-logs:
	@docker logs $(ATTACKER_CONSUMER_VALID_CERT) --tail 120 2>/dev/null || true

.PHONY: attacker-consumer-valid-cert-down
attacker-consumer-valid-cert-down:
	docker rm -f $(ATTACKER_CONSUMER_VALID_CERT) 2>/dev/null || true

.PHONY: attacker-consumer-valid-cert-demo
attacker-consumer-valid-cert-demo:
	$(MAKE) attacker-consumer-valid-cert-up
	sleep 5
	$(MAKE) attacker-consumer-valid-cert-status
	$(MAKE) attacker-consumer-valid-cert-logs

.PHONY: attacker-consumer-invalid-cert-demo
attacker-consumer-invalid-cert-demo:
	$(MAKE) attacker-consumer-invalid-cert-up
	sleep 3
	$(MAKE) attacker-consumer-invalid-cert-status
	$(MAKE) attacker-consumer-invalid-cert-logs

.PHONY: attacker-producer-valid-creds-up
attacker-producer-valid-creds-up:
	docker rm -f $(ATTACKER_PRODUCER_VALID_CREDS) 2>/dev/null || true
	docker run -d --name $(ATTACKER_PRODUCER_VALID_CREDS) --network $(NETWORK) \
		-e BOOTSTRAP_SERVERS="kafka-1:9094,kafka-2:9094,kafka-3:9094" \
		-e TOPIC="$(TOPIC)" \
		-e PRODUCE_INTERVAL_SEC="1" \
		-e KAFKA_SECURITY_PROTOCOL="sasl_ssl" \
		-e KAFKA_SASL_MECHANISM="SCRAM-SHA-256" \
		-e KAFKA_SASL_USERNAME="producer" \
		-e KAFKA_SASL_PASSWORD="producer-secret" \
		-e KAFKA_SSL_CA_LOCATION="/sec/ca.crt" \
		-e KAFKA_DEBUG="security,broker,protocol" \
		-v $(ROOT)/security/ca/ca.crt:/sec/ca.crt:ro \
		$(SIMULATOR_IMAGE)

.PHONY: attacker-producer-valid-creds-status
attacker-producer-valid-creds-status:
	@docker ps -a --filter "name=$(ATTACKER_PRODUCER_VALID_CREDS)"

.PHONY: attacker-producer-valid-creds-logs
attacker-producer-valid-creds-logs:
	@docker logs $(ATTACKER_PRODUCER_VALID_CREDS) --tail 120 2>/dev/null || true

.PHONY: attacker-producer-valid-creds-down
attacker-producer-valid-creds-down:
	docker rm -f $(ATTACKER_PRODUCER_VALID_CREDS) 2>/dev/null || true

.PHONY: attacker-producer-valid-creds-demo
attacker-producer-valid-creds-demo:
	$(MAKE) attacker-producer-valid-creds-up
	sleep 5
	$(MAKE) attacker-producer-valid-creds-status
	$(MAKE) attacker-producer-valid-creds-logs

.PHONY: attacker-producer-wrong-creds-demo
attacker-producer-wrong-creds-demo:
	$(MAKE) attacker-producer-wrong-creds-up
	sleep 3
	$(MAKE) attacker-producer-wrong-creds-status
	$(MAKE) attacker-producer-wrong-creds-logs

.PHONY: attacker-consumer-valid-creds-up
attacker-consumer-valid-creds-up:
	docker rm -f $(ATTACKER_CONSUMER_VALID_CREDS) 2>/dev/null || true
	docker run -d --name $(ATTACKER_CONSUMER_VALID_CREDS) --network $(NETWORK) \
		-e BOOTSTRAP_SERVERS="kafka-1:9094,kafka-2:9094,kafka-3:9094" \
		-e TOPIC="$(TOPIC)" \
		-e GROUP_ID="analytics-group" \
		-e AUTO_OFFSET_RESET="latest" \
		-e KAFKA_SECURITY_PROTOCOL="sasl_ssl" \
		-e KAFKA_SASL_MECHANISM="SCRAM-SHA-256" \
		-e KAFKA_SASL_USERNAME="analytics" \
		-e KAFKA_SASL_PASSWORD="analytics-secret" \
		-e KAFKA_SSL_CA_LOCATION="/sec/ca.crt" \
		-e KAFKA_DEBUG="security,broker,protocol" \
		-v $(ROOT)/security/ca/ca.crt:/sec/ca.crt:ro \
		$(ANALYTICS_IMAGE)

.PHONY: attacker-consumer-valid-creds-status
attacker-consumer-valid-creds-status:
	@docker ps -a --filter "name=$(ATTACKER_CONSUMER_VALID_CREDS)"

.PHONY: attacker-consumer-valid-creds-logs
attacker-consumer-valid-creds-logs:
	@docker logs $(ATTACKER_CONSUMER_VALID_CREDS) --tail 120 2>/dev/null || true

.PHONY: attacker-consumer-valid-creds-down
attacker-consumer-valid-creds-down:
	docker rm -f $(ATTACKER_CONSUMER_VALID_CREDS) 2>/dev/null || true

.PHONY: attacker-consumer-valid-creds-demo
attacker-consumer-valid-creds-demo:
	$(MAKE) attacker-consumer-valid-creds-up
	sleep 5
	$(MAKE) attacker-consumer-valid-creds-status
	$(MAKE) attacker-consumer-valid-creds-logs

.PHONY: attacker-consumer-wrong-creds-demo
attacker-consumer-wrong-creds-demo:
	$(MAKE) attacker-consumer-wrong-creds-up
	sleep 3
	$(MAKE) attacker-consumer-wrong-creds-status
	$(MAKE) attacker-consumer-wrong-creds-logs


.PHONY: fault-demo
fault-demo:
	@echo "== Step 1: Describe events topic before failure =="
	$(MAKE) describe-events
	@echo ""
	@echo "== Step 2: Stop kafka-3 =="
	$(MAKE) broker3-stop
	@sleep 5
	@echo ""
	@echo "== Step 3: Describe events topic after broker failure =="
	$(MAKE) describe-events
	@echo ""
	@echo "== Step 4: Show recent service logs =="
	$(MAKE) logs-simulator
	$(MAKE) logs-analytics
	@echo ""
	@echo "== Step 5: Restart kafka-3 =="
	$(MAKE) broker3-start
	@sleep 8
	@echo ""
	@echo "== Step 6: Describe events topic after recovery =="
	$(MAKE) describe-events

.PHONY: scale-demo
scale-demo:
	@echo "== Step 1: Consumer group before scale-up =="
	$(MAKE) group-describe
	@echo ""
	@echo "== Step 2: Scale analytics to 2 =="
	$(MAKE) scale-analytics-2
	@sleep 8
	@echo ""
	@echo "== Step 3: Consumer group after scale-up =="
	$(MAKE) group-describe
	@echo ""
	@echo "== Step 4: Scale analytics back to 1 =="
	$(MAKE) scale-analytics-1
	@echo ""
	@echo "== Step 5: Consumer group after scale-down =="
	$(MAKE) group-describe
	@echo ""
	@echo "== Step 6: Start kafka-4 cleanly =="
	$(MAKE) broker4-up
	@echo ""
	@echo "== Step 7: Check kafka-4 =="
	$(MAKE) broker4-check
	@echo ""
	@echo "== Step 8: Create and describe broker scaling demo topic =="
	$(MAKE) broker4-topic

.PHONY: clean
clean: attacker-down ui-down
	docker rm -f kafka-4 2>/dev/null || true
	docker rm -f $(PROJECT)-analytics-service-2 2>/dev/null || true

.PHONY: prune
prune:
	docker system prune --volumes -f

.PHONY: docker-clean
docker-clean: prune
