# ShopLite capstone: instructions for Claude

Course capstone (Poridhi "Mastering DevOps and AWS", Batch 03), deadline **17 Nov 2026**. Individual work; the user must explain everything in a 10-minute live demo.

## Read first, every session

1. `PROGRESS.md`: what is done, the commit of each step, decisions taken, and **what to do next**. Start from its "পরের কাজ" section.
2. `project.md`: the question paper. Names, labels, endpoints and file paths in it are graded; match them exactly.
3. `PLAN.md` (Bengali): the full plan with decisions already made (Python 3.12 + FastAPI, k3s, Traefik, Grafana Alloy, SSM, NAT Gateway, S3 lockfile, Slack, k6, ...). Follow them; do not re-open them unless something is impossible.

## How to work with this user

- The user writes in Bengali (sometimes Banglish). Reply in Bengali; keep technical terms, code, commands and errors in English.
- Work in **small steps**, one at a time. Before starting a step, say in a line what it will do. Do not jump ahead to the next step without the user's go-ahead.
- A step is done only when:
  1. unit tests pass (run in Docker, see below);
  2. the real stack was run and the behaviour checked (curl, logs, DB rows);
  3. `PROGRESS.md` is updated: step table status and commit hash, what was done, how it was verified, new decisions, next work;
  4. the change is committed and **pushed to `main`** (the user asked for direct pushes to main; PLAN.md says the same).
- After each step, explain briefly what each new file does and why, so the user can present it.
- Never commit secrets. `.env` is git-ignored; only `.env.example` with placeholder values is committed.

## Repository layout

- `shoplite-app/` and `shoplite-gitops/` are the two repositories the question asks for. They live as subfolders here and will be split out later, so **every path inside them must be relative to that subfolder** (compose, Makefile, CI, Helm).
- Root keeps course docs: `project.md`, `PLAN.md`, `PROGRESS.md`, `architecture-diagram.*`, `OFFICE-PC-GUIDE.md`.
- Target structure of both repos: `project.md` section 2.1 and `PLAN.md` section 3.

## Code conventions already in place (keep them)

- Python 3.12 on `python:3.12-alpine`. Dependencies pinned in each service's `requirements.txt` / `requirements-dev.txt`. To add one, install it in a throwaway `python:3.12-alpine` container, read the resolved version, pin it.
- Dockerfiles: stages `builder` → `test` → `runtime`; runtime runs as uid/gid `10001`, has `HEALTHCHECK`, `.dockerignore`; images must stay **under 150 MB** (now ~105 MB API, ~87 MB worker).
- Config only from environment variables (`config.py`), validated at startup.
- JSON logs on stdout with `timestamp, level, service, message, trace_id` (`logging_setup.py`, identical copy in both services).
- Metrics: exact Q6.2 names/labels; `route` label is the route template; `/healthz`, `/readyz`, `/metrics` are excluded from HTTP metrics, traces and INFO logs.
- Tracing: OTel SDK; spans always created, exported only when `OTEL_EXPORTER_OTLP_ENDPOINT` is set. DB spans are written by hand (no auto-instrumentation). Queue messages carry `traceparent`; the worker continues the same trace.
- `create_app(settings, db, queue)` and `OrderProcessor(store, ...)` take dependencies as arguments; tests use in-memory fakes (`tests/conftest.py`, `tests/fakes.py`), never real Postgres/Redis.

## Commands

Run from `shoplite-app/`:

```bash
cp .env.example .env                       # once per machine
docker compose up -d --build --wait         # postgres, redis, catalog-api, order-worker
docker compose --profile tracing up -d      # + Jaeger UI on http://127.0.0.1:16686 (needs OTEL_EXPORTER_OTLP_ENDPOINT=http://jaeger:4318 in .env)
docker compose logs -f catalog-api order-worker
```

Unit tests of one service (`catalog-api` or `order-worker`):

```bash
docker build --target test -t shoplite/catalog-api:test services/catalog-api && docker run --rm shoplite/catalog-api:test
```

API docs: http://127.0.0.1:8000/docs. The worker's `/healthz` and `/metrics` are on port 8001 inside the container only (`docker compose exec order-worker wget -qO- http://127.0.0.1:8001/metrics`).

## Gotchas found so far

- Windows Git Bash rewrites absolute paths in arguments (`/opt/venv/...` becomes `C:/Program Files/Git/...`). Prefix such `docker run` commands with `MSYS_NO_PATHCONV=1`.
- `core.autocrlf=true` on Windows: `.gitattributes` in both subfolders forces LF. Keep it; shell scripts must be LF.
- `make` may be missing on Windows. Run the equivalent commands directly; the Makefile itself must target Linux (AWS lab).
- Jaeger 2.23's HTTP API is `/api/v3/...` (the old `/api/traces` returns 404).
- New OTel SDK sets `traceparent` flags to `03` (sampled + random), not `01`.
- `init.sql` runs only when the `pgdata` volume is empty; after a schema change use `docker compose down -v` (wipes local data).

## Next work (details in PROGRESS.md)

**Step 7: chaos flags** (Q1.5, all off by default; used in Q8):

| Variable | Service | Effect |
|---|---|---|
| `CHAOS_LATENCY_MS` | catalog-api | adds that delay to ~30% of `GET /products/{id}` |
| `CHAOS_ERROR_RATE` | catalog-api | returns HTTP 500 for that fraction (0.1 = 10%) of `POST /orders`, before touching the DB |
| `CHAOS_MEMORY_LEAK` | order-worker | keeps ~1 MB per processed order in a growing list (OOMKilled within ~15 min under load) |
| `CHAOS_SLOW_DB` | order-worker | runs `SELECT pg_sleep(2)` before each DB update (visible as a DB span) |

Rules: parse in `config.py` with validation; never log flag values or mention "chaos" in logs, errors or span names (Q8 must be solved from observability, not by reading the flag); inject the random source so tests are deterministic; pass the variables through `docker-compose.yml` with `:-` defaults; add tests.

**Step 9: web** (`services/web/`): static HTML/JS on `nginxinc/nginx-unprivileged` (port 8080, non-root), multi-stage Dockerfile, `HEALTHCHECK`, `/healthz`. Page lists products, places an order, polls its status until `COMPLETED`/`FAILED`. Calls go to `/api/...`; nginx proxies `/api/` to catalog-api with the prefix stripped (upstream from an env var; use a `resolver` + variable so nginx starts even if the upstream name does not resolve yet). `Cache-Control: no-cache` on `index.html` (Q7 checkpoint changes the page `<title>`).

**Then Q2:** add web to compose (only web published, `${WEB_PORT:-80}:8080`), `scripts/smoke-test.sh` (starts the stack, waits for `/api/readyz`, places an order, polls until `COMPLETED`, non-zero exit on any failure, no `jq`), `Makefile` with `build up down test smoke` (creates `.env` from `.env.example` if missing). Checkpoint: `make up && make smoke` on a clean Linux machine.

After Q2 the work moves to the AWS lab (Q3 → Q8); follow PLAN.md sections 5 and 6.
