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
- Dockerfiles: stages `builder` → `test` → `runtime`; runtime runs as uid/gid `10001`, has `HEALTHCHECK`, `.dockerignore`; images must stay **under 150 MB** (unpacked now 122.6 MB API, 101.4 MB worker; see the Docker 29 gotcha).
- Config only from environment variables (`config.py`), validated at startup.
- JSON logs on stdout with `timestamp, level, service, message, trace_id` (`logging_setup.py`, identical copy in both services).
- Metrics: exact Q6.2 names/labels; `route` label is the route template; `/healthz`, `/readyz`, `/metrics` are excluded from HTTP metrics, traces and INFO logs.
- Tracing: OTel SDK; spans always created, exported only when `OTEL_EXPORTER_OTLP_ENDPOINT` is set. DB spans are written by hand (no auto-instrumentation). Queue messages carry `traceparent`; the worker continues the same trace.
- `create_app(settings, db, queue, faults)`, `OrderProcessor(store, ...)` and `OrderStore(settings, pool)` take dependencies as arguments; tests use in-memory fakes (`tests/conftest.py`, `tests/fakes.py`), never real Postgres/Redis.
- Chaos flags (Q1.5, Step 7, all off by default): `CHAOS_LATENCY_MS` and `CHAOS_ERROR_RATE` in catalog-api `app/faults.py` (`FaultInjector`, injectable `rng` and `sleep`); `CHAOS_MEMORY_LEAK` in worker `processor.py`, `CHAOS_SLOW_DB` in worker `store.py`. Never name a flag or print its value in logs, error bodies or span names (Q8 must be solved from observability). Keep comments that name a flag on their own line, never beside an executing line: tracebacks print the executing line.

## Commands

Run from `shoplite-app/`:

```bash
cp .env.example .env                       # once per machine
docker compose up -d --build --wait         # postgres, redis, catalog-api, order-worker
docker compose --profile tracing up -d      # + Jaeger UI on http://127.0.0.1:16686 (needs OTEL_EXPORTER_OTLP_ENDPOINT=http://jaeger:4318 in .env)
docker compose logs -f catalog-api order-worker
CHAOS_SLOW_DB=true docker compose up -d --wait   # turn one chaos flag on; rerun without it to turn it off
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
- Jaeger 2.23's HTTP API is `/api/v3/...` (the old `/api/traces` returns 404). `/api/v3/traces` takes `query.service_name`, `query.operation_name`, `query.start_time_min`/`max` (RFC 3339), `query.search_depth`, `query.duration_min`; span status codes are numeric (2 = ERROR).
- No `jq` or Python on the Windows host: parse JSON with `docker run --rm -i python:3.12-alpine python -c "..."`.
- Docker 29 on this PC uses the containerd image store: `docker images` shows DISK USAGE (unpacked + compressed, 159 MB for the API) and CONTENT SIZE (compressed, 36.6 MB). The unpacked size is the sum of `docker history --human=false --format '{{.Size}}'` (122.6 MB API). Q2 drops pip (13 MB) from the runtime venv so DISK USAGE is under 150 MB too.
- curl on Windows measures delays served from Docker slightly short (a 0.5 s sleep reads 0.498 s). Judge latency from the server's histogram.
- New OTel SDK sets `traceparent` flags to `03` (sampled + random), not `01`.
- `init.sql` runs only when the `pgdata` volume is empty; after a schema change use `docker compose down -v` (wipes local data).

## Next work (details in PROGRESS.md)

Order agreed with the user on 12 Nov: finish the application first (Step 9, then Q2), then write the infrastructure code (Q3 Linux files, Q4 Terraform and Ansible, Q5 Helm, Q6 monitoring, Q7 workflows) on this PC, and use the AWS lab only to run it and take evidence.

**Step 9: web** (`services/web/`): static HTML/JS on `nginxinc/nginx-unprivileged` (port 8080, non-root), multi-stage Dockerfile, `HEALTHCHECK`, `/healthz`. Page lists products, places an order, polls its status until `COMPLETED`/`FAILED`. Calls go to `/api/...`; nginx proxies `/api/` to catalog-api with the prefix stripped (upstream from an env var; use a `resolver` + variable so nginx starts even if the upstream name does not resolve yet). `Cache-Control: no-cache` on `index.html` (Q7 checkpoint changes the page `<title>`).

**Then Q2:** add web to compose (only web published, `${WEB_PORT:-80}:8080`), `scripts/smoke-test.sh` (starts the stack, waits for `/api/readyz`, places an order, polls until `COMPLETED`, non-zero exit on any failure, no `jq`), `Makefile` with `build up down test smoke` (creates `.env` from `.env.example` if missing). Also drop pip from the runtime venv (see the Docker 29 gotcha). Checkpoint: `make up && make smoke` on a clean Linux machine.

After Q2: infrastructure code on this PC, then the AWS lab (Q3 → Q8); follow PLAN.md sections 5 and 6.
