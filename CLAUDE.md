# ShopLite capstone: instructions for Claude

Course capstone (Poridhi "Mastering DevOps and AWS", Batch 03), deadline **17 Nov 2026**. Individual work; the user must explain everything in a 10-minute live demo.

## Read first, every session

1. `PROGRESS.md`: what is done, the commit of each step, decisions taken, and **what to do next**. Start from its "পরের কাজ" section.
2. `project.md`: the question paper. Names, labels, endpoints and file paths in it are graded; match them exactly.
3. `PLAN.md` (Bengali): the full plan with decisions already made (Python 3.12 + FastAPI, k3s, Traefik, Grafana Alloy, SSM, NAT Gateway, S3 lockfile, Slack, k6, ...). Follow them; do not re-open them unless something is impossible.

## How to work with this user

- **Build only what `project.md` asks for** (the user's rule, 12 Nov). No extra tools, services or features for convenience: Jaeger, a version footer and extra published ports were removed for this reason. Files needed to make the project reproducible are fine, because the question allows them. Time pressure is never a reason to skip or shortcut something the question asks. If something not asked looks useful, propose it and let the user decide; do not add it.
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
- Dockerfiles: API and worker have stages `builder` → `test` → `runtime`; the venv is created `--without-pip` and the base image's pip installs into it with `--python`. web has `test` → `runtime`. Runtime runs as uid/gid `10001` (web: the nginx image's own uid 101), has `HEALTHCHECK`, `.dockerignore`. Images must stay **under 150 MB**: unpacked now 64.6 MB web, 109.2 MB API, 88.0 MB worker (see the Docker 29 gotcha).
- web (`services/web/`): `nginxinc/nginx-unprivileged:1.30.6-alpine`, port 8080. `nginx/default.conf.template` is rendered by the image's entrypoint at start (`API_UPSTREAM`, DNS from resolv.conf via `NGINX_ENTRYPOINT_LOCAL_RESOLVERS=1`); `proxy_pass` uses a variable so nginx starts without the upstream. `/api/` strips the prefix and keeps the query; `Cache-Control: no-cache` on static files (the Q7 checkpoint changes `<title>`); `/healthz`; JSON access log with the five fields (level from status). Its "unit tests" are `tests/run.sh` (15 checks against a fake API) in the test stage.
- Compose (`docker-compose.yml`): exactly the five components. Only web is published (`${WEB_PORT:-80}:8080`; `WEB_PORT` may be `IP:PORT`); the API is reached through web's `/api/`. `depends_on` uses `service_healthy`. No trace backend in compose: spans are created (trace_id in logs) but exported only when `OTEL_EXPORTER_OTLP_ENDPOINT` is set, which happens in Kubernetes (Tempo).
- `scripts/smoke-test.sh` (POSIX sh, curl and sed, no jq) goes through web: up, `/api/readyz`, POST `/api/orders`, poll until `COMPLETED`. `Makefile` targets: `build up down test smoke`; `.env` is copied from `.env.example` on first use.
- Config only from environment variables (`config.py`), validated at startup.
- JSON logs on stdout with `timestamp, level, service, message, trace_id` (`logging_setup.py`, identical copy in both services).
- Metrics: exact Q6.2 names/labels; `route` label is the route template; `/healthz`, `/readyz`, `/metrics` are excluded from HTTP metrics, traces and INFO logs.
- Tracing: OTel SDK; spans always created, exported over OTLP only when `OTEL_EXPORTER_OTLP_ENDPOINT` is set. DB spans are written by hand (no auto-instrumentation). Queue messages carry `traceparent`; the worker continues the same trace.
- `create_app(settings, db, queue, faults)`, `OrderProcessor(store, ...)` and `OrderStore(settings, pool)` take dependencies as arguments; tests use in-memory fakes (`tests/conftest.py`, `tests/fakes.py`), never real Postgres/Redis.
- Chaos flags (Q1.5, Step 7, all off by default): `CHAOS_LATENCY_MS` and `CHAOS_ERROR_RATE` in catalog-api `app/faults.py` (`FaultInjector`, injectable `rng` and `sleep`); `CHAOS_MEMORY_LEAK` in worker `processor.py`, `CHAOS_SLOW_DB` in worker `store.py`. Never name a flag or print its value in logs, error bodies or span names (Q8 must be solved from observability). Keep comments that name a flag on their own line, never beside an executing line: tracebacks print the executing line.

## Commands

Run from `shoplite-app/`. On Linux (and the question's checkpoint):

```bash
make up && make smoke       # .env from .env.example if missing, build, start, wait healthy, smoke test
make test                   # unit tests of web, catalog-api and order-worker in Docker
make down                   # stop; the pgdata volume stays
```

Windows Git Bash has no `make`; the same by hand:

```bash
cp .env.example .env                                    # once per machine
docker compose up -d --build --wait && sh scripts/smoke-test.sh
docker build --target test -t shoplite/catalog-api:test services/catalog-api && docker run --rm shoplite/catalog-api:test
docker compose logs -f
CHAOS_SLOW_DB=true docker compose up -d --wait          # turn one chaos flag on; rerun without it to turn it off
```

On PC-01 real `make` runs in WSL Ubuntu: `wsl.exe -d Ubuntu --cd /mnt/e/devops-final/shoplite-app -- make up` (see the WSL gotcha for anything longer).

The page is at `http://127.0.0.1:<WEB_PORT>` (PC-01: http://127.0.0.1:8088); the API through it at `/api/...` (`/api/readyz`, `/api/products`, `/api/metrics`). The worker's `/healthz` and `/metrics` are on port 8001 inside its container only (`docker compose exec order-worker wget -qO- http://127.0.0.1:8001/metrics`).

## Gotchas found so far

- Windows Git Bash rewrites absolute paths and `X:\...` paths in arguments (`/opt/venv/...` becomes `C:/Program Files/Git/...`). Prefix such `docker run`, `docker exec` and `wsl.exe` commands with `MSYS_NO_PATHCONV=1`.
- On PC-01 (the Windows machine with the repo at `E:\devops-final`) port 80 is taken by `httpd` and 8080 by a `php` process (the user's own; leave them). Its `.env` has `WEB_PORT=127.0.0.1:8088`; keep the default 80 for the clean lab machine.
- WSL Ubuntu 24.04 on PC-01 has `make`, `docker` (same Docker Desktop daemon) and `curl`. Its default shell is zsh: `wsl.exe -- bash -c '...'` lets zsh expand `$(...)` first, in the wrong folder. Put longer commands in a script file and run `wsl.exe -d Ubuntu -- bash <file>`.
- For a clean-machine check, clone into WSL and run with `COMPOSE_PROJECT_NAME=<other>` and another `WEB_PORT`, so the running stack and its volume stay untouched; remove the test volume and clone afterwards.
- nginx's `resolver` ignores search domains: in Kubernetes `API_UPSTREAM` needs the full service name (`catalog-api.<namespace>.svc.cluster.local:8000`).
- The built-in browser's screenshots time out while the Claude window is hidden; check pages with `get_page_text`, `find` and `javascript_tool` instead. Compare page width with `document.documentElement.clientWidth`, not `innerWidth` (that includes the scrollbar).
- `core.autocrlf=true` on Windows: `.gitattributes` in both subfolders forces LF. Keep it; shell scripts must be LF. Mark scripts executable in Git with `git add --chmod=+x`.
- `make` is missing on Windows itself. The Makefile must target Linux (AWS lab).
- No `jq` or Python on the Windows host: parse JSON with `docker run --rm -i python:3.12-alpine python -c "..."`.
- Docker 29 on PC-01 uses the containerd image store (other new installs may too): `docker images` shows DISK USAGE (unpacked + compressed: 90 MB web, 142 MB API, 114 MB worker) and CONTENT SIZE (compressed). The unpacked size is the sum of `docker history --human=false --format '{{.Size}}'`.
- curl on Windows measures delays served from Docker slightly short (a 0.5 s sleep reads 0.498 s). Judge latency from the server's histogram.
- New OTel SDK sets `traceparent` flags to `03` (sampled + random), not `01`.
- `init.sql` runs only when the `pgdata` volume is empty; after a schema change use `docker compose down -v` (wipes local data).

## Next work (details in PROGRESS.md)

Q1 and Q2 are done. Order agreed with the user on 12 Nov: write the infrastructure code on the user's own PC (Q3 Linux files, Q4 Terraform and Ansible, Q5 Helm, Q6 monitoring, Q7 workflows), and use the AWS lab only to run it and take evidence (Q3 → Q8; PLAN.md sections 5 and 6).

**Q3 (next):** the `linux/` folder from `project.md` 3.1–3.4 and PLAN Phase 4: `sshd_config` (no root login, no password login), commands for the `deploy` user and `ops` group, `/var/log/shoplite/` permissions (chown, chmod, exactly one setfacl), `systemd/` with `shoplite-backup.service` (`Restart=on-failure`) and `shoplite-backup.timer` (nightly `pg_dump` into `/var/backups/shoplite/`), `firewall/` (UFW: deny incoming by default, allow only 22, 80, 443), and `evidence/` for the lab screenshots. They are applied and evidenced on the lab's Ubuntu EC2, which is also the clean machine for Q2's checkpoint video.
