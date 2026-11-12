# ShopLite local stack (question 2d). Run from this folder on Linux:
#   make up && make smoke
# Everything runs in Docker, so the machine needs only Docker (with Compose), make and curl.

COMPOSE := docker compose
SERVICES := web catalog-api order-worker

.PHONY: build up down test smoke

# Build the three application images.
build: .env
	$(COMPOSE) build

# Build if needed, start all five components and wait until they are healthy.
up: .env
	$(COMPOSE) up -d --build --wait

# Stop and remove the containers; the Postgres data volume is kept.
down: .env
	$(COMPOSE) down

# Unit tests of each service, inside Docker (the `test` stage of its Dockerfile).
test:
	@set -e; for svc in $(SERVICES); do \
		echo "== $$svc"; \
		docker build -q --target test -t shoplite/$$svc:test services/$$svc >/dev/null; \
		docker run --rm shoplite/$$svc:test; \
	done

# End-to-end check through the web container: readyz, one order, COMPLETED.
smoke: .env
	sh scripts/smoke-test.sh

# Compose reads its settings from .env; a fresh clone gets a copy of the example once.
.env:
	cp .env.example .env
