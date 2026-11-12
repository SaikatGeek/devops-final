#!/bin/sh
# Checks of the web image, run by its test stage (from services/web):
#   docker build --target test -t shoplite/web:test . && docker run --rm shoplite/web:test
# The real config is used; a fake API (fake-api.conf, 127.0.0.1:9000) stands in for catalog-api.
set -u

WEB=http://127.0.0.1:8080
LOGS=$(mktemp -d)  # nginx's access log (stdout) and error log (stderr) go here
failures=0

check() {  # check DESCRIPTION COMMAND...: run the command quietly, count a failure
  description=$1
  shift
  if "$@" >/dev/null 2>&1; then
    echo "ok    $description"
  else
    echo "FAIL  $description"
    failures=$((failures + 1))
  fi
}
status_of() { curl -s -o /dev/null -w '%{http_code}' "$WEB$1"; }
body_of() { curl -fsS "$WEB$1"; }

# Every access-log line must start with the five fields the question asks for.
access_log_is_json() {
  test -s "$LOGS/access.log" &&
    ! grep -v '^{"timestamp":"[^"]*","level":"[A-Z]*","service":"web","message":"request completed","trace_id":null,' "$LOGS/access.log"
}

# 1. proxy_pass uses a variable, so the config is valid (and nginx starts) even when the
#    upstream name does not resolve. A plain `proxy_pass http://name:port` would fail here.
check "config is valid with an unresolvable upstream" \
  env API_UPSTREAM=no-such-host.invalid:8000 /docker-entrypoint.sh nginx -t

# 2. Render the template again with the fake API and start nginx in the background.
if ! /docker-entrypoint.sh nginx >"$LOGS/access.log" 2>"$LOGS/error.log"; then
  echo "FAIL  nginx did not start"
  cat "$LOGS/error.log"
  exit 1
fi
for _ in $(seq 50); do
  curl -fs "$WEB/healthz" >/dev/null 2>&1 && break
  sleep 0.1
done

check "runs as a non-root user" test "$(id -u)" -ne 0
check "/healthz answers 200 with a JSON body" test "$(body_of /healthz)" = '{"status":"ok"}'
check "/ serves the page with its title" sh -c "curl -fsS $WEB/ | grep -q '<title>ShopLite</title>'"
check "the page is sent with Cache-Control: no-cache" sh -c "curl -sI $WEB/ | grep -qi '^cache-control: no-cache'"
check "app.js and style.css are served" test "$(status_of /app.js) $(status_of /style.css)" = "200 200"
check "a missing file gives 404" test "$(status_of /no-such-file.html)" = 404
check "/api/ drops the prefix and keeps the query" test "$(body_of '/api/products/3?x=1')" = "/products/3?x=1"
check "/api/orders reaches the API as /orders" test "$(body_of /api/orders)" = "/orders"
check "an upstream 5xx is passed through" test "$(status_of /api/broken)" = 502
check "the server version is not advertised" sh -c "curl -sI $WEB/ | grep -i '^server:' | grep -qv '[0-9]'"
check "access log lines are JSON with timestamp, level, service, message, trace_id" access_log_is_json
check "a 404 is logged as WARNING" grep -q '"level":"WARNING".*"status":404' "$LOGS/access.log"
check "a 5xx is logged as ERROR" grep -q '"level":"ERROR".*"status":502' "$LOGS/access.log"
check "/healthz is not logged" sh -c "! grep -q /healthz $LOGS/access.log"

nginx -s quit 2>/dev/null
echo
if [ "$failures" -ne 0 ]; then
  echo "$failures check(s) failed; nginx error log:"
  cat "$LOGS/error.log"
  exit 1
fi
echo "all checks passed"
