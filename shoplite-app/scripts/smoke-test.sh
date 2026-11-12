#!/bin/sh
# ShopLite smoke test (question 2c): start the stack, wait until /readyz answers,
# place an order, and poll it until it is COMPLETED. Any failed step exits non-zero.
# Needs Docker Compose and curl (no jq). Run it from anywhere: scripts/smoke-test.sh
set -eu

cd "$(dirname "$0")/.."  # the shoplite-app folder, where docker-compose.yml is

READY_TIMEOUT=120  # seconds for the stack to become ready (the first start initialises Postgres)
ORDER_TIMEOUT=60   # seconds for the order to reach COMPLETED

log() { echo "[smoke] $*"; }
fail() {
  echo "[smoke] FAIL: $*" >&2
  docker compose ps >&2 || true
  exit 1
}

command -v curl >/dev/null 2>&1 || fail "curl is not installed"

# 1. Start the application stack (images that do not exist yet are built).
log "starting the stack"
docker compose up -d || fail "docker compose up failed"

# web is the only published service; ask Compose which host port it got (WEB_PORT).
address=$(docker compose port web 8080 | head -n 1)
[ -n "$address" ] || fail "web has no published port"
BASE="http://127.0.0.1:${address##*:}"

# 2. Wait until /readyz answers 200, i.e. the database and the queue are reachable.
log "waiting for $BASE/api/readyz"
waited=0
until [ "$(curl -s -o /dev/null -w '%{http_code}' "$BASE/api/readyz")" = 200 ]; do
  [ "$waited" -lt "$READY_TIMEOUT" ] || fail "/readyz did not answer 200 within ${READY_TIMEOUT}s"
  sleep 2
  waited=$((waited + 2))
done
log "ready after ${waited}s"

# 3. Place an order: 201 with the new order's id is expected.
response=$(curl -s -w '\n%{http_code}' -H 'Content-Type: application/json' \
  -d '{"product_id": 1, "quantity": 2}' "$BASE/api/orders") || fail "POST /orders got no answer"
status=$(printf '%s\n' "$response" | tail -n 1)
body=$(printf '%s\n' "$response" | sed '$d')
[ "$status" = 201 ] || fail "POST /orders answered HTTP $status: $body"
order_id=$(printf '%s' "$body" | sed -n 's/.*"id":\([0-9][0-9]*\).*/\1/p')
[ -n "$order_id" ] || fail "no order id in the answer: $body"
log "placed order $order_id"

# 4. Poll the order until it is COMPLETED; FAILED or a timeout fails the test.
waited=0
last=""
while :; do
  body=$(curl -s "$BASE/api/orders/$order_id") || body=""
  current=$(printf '%s' "$body" | sed -n 's/.*"status":"\([A-Z]*\)".*/\1/p')
  if [ "$current" != "$last" ]; then
    log "order $order_id is ${current:-not readable}"
    last=$current
  fi
  case $current in
    COMPLETED) break ;;
    FAILED) fail "order $order_id FAILED" ;;
  esac
  [ "$waited" -lt "$ORDER_TIMEOUT" ] || fail "order $order_id not COMPLETED within ${ORDER_TIMEOUT}s"
  sleep 1
  waited=$((waited + 1))
done

log "PASS: order $order_id COMPLETED"
