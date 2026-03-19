SHELL := /bin/bash

PROJECT := kafka-project

DC := docker compose

BASE := -f docker-compose.yml
KRAFT := -f docker-compose-kafka-kraft.yml
SERV_SASL := -f docker-compose-services-sasl.yml
AN_SCALE := -f docker-compose-analytics-scale.yml
KAFKA4 := -f docker-compose-kafka4.yml

COMPOSE_CORE := $(BASE) $(KRAFT) $(SERV_SASL)
COMPOSE_WITH_SCALE := $(BASE) $(KRAFT) $(SERV_SASL) $(AN_SCALE)
COMPOSE_WITH_KAFKA4 := $(BASE) $(KRAFT) $(SERV_SASL) $(KAFKA4)
COMPOSE_ALL := $(BASE) $(KRAFT) $(SERV_SASL) $(KAFKA4) $(AN_SCALE)

.PHONY: help ps logs kafka-up kafka-down services-up services-down up down stop start restart clean prune \
        analytics-scale-1 analytics-scale-2 simulator-scale-1 simulator-scale-2 \
        kafka4-up kafka4-down kafka4-ps topic-create acls-list

help:
	@echo ""
	@echo "Targets:"
	@echo "  make up                -> Start Kafka (kraft) + services (SASL_SSL)"
	@echo "  make down              -> Stop & remove containers (keeps volumes)"
	@echo "  make clean             -> Stop & remove containers + volumes (DATA RESET)"
	@echo "  make ps                -> Show running containers"
	@echo "  make logs              -> Tail logs (all)"
	@echo ""
	@echo "Kafka only:"
	@echo "  make kafka-up           -> Start kafka-1..3"
	@echo "  make kafka-down         -> Stop kafka-1..3 (keeps volumes)"
	@echo ""
	@echo "Services only:"
	@echo "  make services-up        -> Start analytics-service + simulator-service"
	@echo "  make services-down      -> Stop services"
	@echo ""
	@echo "Scaling (demo):"
	@echo "  make analytics-scale-2  -> Run 2 analytics consumers (needs analytics-scale override)"
	@echo "  make analytics-scale-1  -> Back to 1 analytics consumer"
	@echo "  make simulator-scale-2  -> Run 2 simulators"
	@echo "  make simulator-scale-1  -> Back to 1 simulator"
	@echo ""
	@echo "Kafka-4 (broker scaling demo):"
	@echo "  make kafka4-up          -> Start kafka-4"
	@echo "  make kafka4-down        -> Remove kafka-4"
	@echo "  make kafka4-ps          -> Show kafka-4 status"
	@echo ""
	@echo "Common ops:"
	@echo "  make topic-create       -> Create 'events' topic (idempotent-ish)"
	@echo "  make acls-list          -> List ACLs (head)"
	@echo "  make prune              -> docker system prune --volumes -f"
	@echo ""

ps:
	$(DC) $(COMPOSE_ALL) ps

logs:
	$(DC) $(COMPOSE_ALL) logs -f --tail=200

up:
	$(DC) $(COMPOSE_CORE) up -d --build

down:
	$(DC) $(COMPOSE_CORE) down

stop:
	$(DC) $(COMPOSE_ALL) stop

start:
	$(DC) $(COMPOSE_ALL) start

restart:
	$(DC) $(COMPOSE_ALL) restart

clean:
	$(DC) $(COMPOSE_ALL) down -v --remove-orphans

prune:
	docker system prune --volumes -f

kafka-up:
	$(DC) $(BASE) $(KRAFT) up -d

kafka-down:
	$(DC) $(BASE) $(KRAFT) down

services-up:
	$(DC) $(BASE) $(KRAFT) $(SERV_SASL) up -d --build analytics-service simulator-service

services-down:
	$(DC) $(BASE) $(KRAFT) $(SERV_SASL) stop analytics-service simulator-service

analytics-scale-2:
	$(DC) $(COMPOSE_WITH_SCALE) up -d --no-recreate --scale analytics-service=2 analytics-service

analytics-scale-1:
	$(DC) $(COMPOSE_WITH_SCALE) up -d --no-recreate --scale analytics-service=1 analytics-service

simulator-scale-2:
	$(DC) $(COMPOSE_CORE) up -d --no-recreate --scale simulator-service=2 simulator-service

simulator-scale-1:
	$(DC) $(COMPOSE_CORE) up -d --no-recreate --scale simulator-service=1 simulator-service

kafka4-up:
	$(DC) $(COMPOSE_WITH_KAFKA4) up -d kafka-4

kafka4-down:
	$(DC) $(COMPOSE_WITH_KAFKA4) rm -f -s kafka-4 || true
	docker volume rm $(PROJECT)_kafka4-data 2>/dev/null || true

kafka4-ps:
	$(DC) $(COMPOSE_WITH_KAFKA4) ps kafka-4

topic-create:
	docker exec -it kafka-1 bash -lc '\
kafka-topics --bootstrap-server kafka-1:9092 \
  --create --topic events --partitions 6 --replication-factor 3 \
  --config min.insync.replicas=2 || true'

acls-list:
	docker exec -it kafka-1 bash -lc 'kafka-acls --bootstrap-server kafka-1:9092 --list 2>&1 | head -n 80 || true'
