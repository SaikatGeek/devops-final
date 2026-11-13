# ShopLite capstone: instructions for Claude

Course capstone (Poridhi "Mastering DevOps and AWS", Batch 03), deadline **17 Nov 2026**. Individual work; the user must explain everything in a 10-minute live demo.

## Read first, every session

1. `PROGRESS.md`: what is done, the commit of each step, decisions taken, and **what to do next**. Start from its "পরের কাজ" section.
2. `project.md`: the question paper. Names, labels, endpoints and file paths in it are graded; match them exactly.
3. When the user has just switched PCs (office PC-01 ↔ home PC), the PC needs `OFFICE-PC-GUIDE.md` section ৯ first (`git pull`, `docker compose down --remove-orphans` to drop an old Jaeger container, `.env` check, smoke test). Claude's memory stays on each PC; everything needed is in this file and `PROGRESS.md`.
4. `PLAN.md` (Bengali): the full plan with decisions already made (Python 3.12 + FastAPI, k3s, Traefik, Grafana Alloy, SSM, NAT Gateway, S3 lockfile, Slack, k6, ...). Follow them; do not re-open them unless something is impossible.

## How to work with this user

- **Build only what `project.md` asks for** (the user's rule, 12 Nov). No extra tools, services or features for convenience: Jaeger, a version footer and extra published ports were removed for this reason. Files needed to make the project reproducible are fine, because the question allows them. Time pressure is never a reason to skip or shortcut something the question asks. If something not asked looks useful, propose it and let the user decide; do not add it.
- The user writes in Bengali (sometimes Banglish). Reply in Bengali; keep technical terms, code, commands and errors in English. Keep replies and explanations short and to the point (the user asked for this on 12 Nov).
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
- `linux/` (Q3): `sshd_config` (Ubuntu 24.04 default plus PermitRootLogin, PasswordAuthentication, KbdInteractiveAuthentication and PubkeyAuthentication placed **before** the Include, because sshd keeps the first value), `systemd/shoplite-backup.{service,timer,sh}` (oneshot, Restart=on-failure 5 min, 3 starts/h; nightly 02:00; `docker compose -p shoplite exec -T postgres pg_dump` with the container's env, root-only `.sql` in `/var/backups/shoplite`), `firewall/ufw.sh`, and `evidence/commands.md` (English; the lab procedure, expected output and screenshot list). The Ansible `hardening` role in Q4 must apply the same files.
- `terraform/` (Q4): Terraform 1.17.2 (image `hashicorp/terraform:1.17.2`), AWS provider `~> 6.73` locked at 6.73.0 (commit `.terraform.lock.hcl`). `bootstrap/` creates the state bucket `shoplite-tfstate-<account>-<region>` (versioning, force_destroy, local state). The root uses a partial S3 backend (`key`, `encrypt`, `use_lockfile` in `backend.tf`; bucket and region via `-backend-config` at init), provider `default_tags` `project=shoplite`, and the USD 20 budget (`budget_alert_email` only via `TF_VAR_`, never in Git). Modules go in `terraform/modules/{network,compute,alb,ecr}` with their own `required_providers`. Every module and root config has `tests/*.tftest.hcl` with `mock_provider "aws"`, so `terraform test` runs without AWS; the real apply happens only in the lab. In tests use `command = apply` (mock apply, offline) to compare ids between resources, mock data sources with `mock_data` (e.g. `aws_availability_zones` names), and write explicitly in the code any value a test checks (the mock leaves provider defaults null). The provider still validates ARN arguments under a mock: give resources whose ARN is passed on (`aws_lb`, `aws_lb_target_group`) well-formed ARNs with `mock_resource`, and per-instance values with `override_resource { target = res["key"] }`. After a module change run `init -backend=false` in the root again. Q4 is split into steps 4.1–4.8 (PROGRESS section 5).
- `ansible/` (Q4g): ansible-core 2.21.6 (`requirements.txt`; 2.22 needs Python 3.13, the lab's Ubuntu 24.04 has 3.12), ansible.posix 2.2.2 and community.general 14.0.1 (`requirements.yml`). Groups `control_plane`, `workers`, `k3s_cluster`. Role `hardening` applies Q3's 3.1, 3.2 and 3.4 with `linux/sshd_config` itself (`{{ playbook_dir }}/../linux/sshd_config`, validated with `sshd -t`) and UFW via `community.general.ufw` (22/80/443 like `linux/firewall/ufw.sh`; from `vpc_cidr` 8472/udp, 10250, 9100, and 6443 via `group_vars/control_plane.yml`; everything from the k3s pod and service CIDRs; routed allow). Role `container_runtime`: `overlay` and `br_netfilter` (modprobe only when the feature's path is missing), sysctls, and the k3s binary pinned in `group_vars/k3s_cluster.yml` (`k3s_version: v1.37.2+k3s1`) from the GitHub release with its sha256 (k3s's own containerd is the container runtime; no install script); `tasks/verify.yml` runs after k3s starts. `k3s_server` (config.yaml mode 0600 with Traefik disabled, systemd unit like the install script's, waits for `/readyz`, the token and node Ready), `k3s_agent` (reads `node-token` from the running server, never in Git), `kubeconfig` (k3s.yaml to `{{ playbook_dir }}/kubeconfig`, 0600, server `https://127.0.0.1:6443` for an SSM port forward). `k3s_kubelet_args` stays empty for EC2 (cgroup v2). Every play in `site.yml` has `any_errors_fatal`. `.gitignore` re-includes `roles/kubeconfig/` (its `kubeconfig*` rule hid the role). `ansible/tests/run.sh` rehearses on three systemd containers (subnet 10.99.0.0/24 plays the VPC; nodes get `--cgroupns=private` and volumes for `/var/lib/rancher/k3s` and `/var/lib/kubelet`) and fails unless the second run has `changed=0`, `tests/verify.yml` passes (it loads `../group_vars/k3s_cluster.yml` itself) and the cluster checks pass (three Ready nodes, CoreDNS, `kubectl top nodes` for every node, the fetched kubeconfig); extend it with every new role.
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

Terraform (no install needed; from `shoplite-app/`; on Linux use `$PWD` instead of `$(pwd -W)`):

```bash
TF="docker run --rm -v $(pwd -W)/terraform:/tf -w /tf hashicorp/terraform:1.17.2"
MSYS_NO_PATHCONV=1 $TF fmt -check -recursive
MSYS_NO_PATHCONV=1 $TF -chdir=bootstrap init -backend=false && MSYS_NO_PATHCONV=1 $TF -chdir=bootstrap test
MSYS_NO_PATHCONV=1 $TF init -backend=false && MSYS_NO_PATHCONV=1 $TF validate && MSYS_NO_PATHCONV=1 $TF test
```

Ansible rehearsal (Docker and internet; 5–10 minutes, mostly the k3s download; cleans up after itself): `bash ansible/tests/run.sh`. Run it in the background and redirect its output to a file; the playbook's own log goes to a temp folder (`/tmp/tmp.*/run1.log`).

On PC-01 real `make` runs in WSL Ubuntu: `wsl.exe -d Ubuntu --cd /mnt/e/devops-final/shoplite-app -- make up` (see the WSL gotcha for anything longer).

The page is at `http://127.0.0.1:<WEB_PORT>` (PC-01: http://127.0.0.1:8088); the API through it at `/api/...` (`/api/readyz`, `/api/products`, `/api/metrics`). The worker's `/healthz` and `/metrics` are on port 8001 inside its container only (`docker compose exec order-worker wget -qO- http://127.0.0.1:8001/metrics`).

## Gotchas found so far

- Windows Git Bash rewrites absolute paths and `X:\...` paths in arguments (`/opt/venv/...` becomes `C:/Program Files/Git/...`). Prefix such `docker run`, `docker exec` and `wsl.exe` commands with `MSYS_NO_PATHCONV=1`.
- On PC-01 (the Windows machine with the repo at `E:\devops-final`) port 80 is taken by `httpd` and 8080 by a `php` process (the user's own; leave them). Its `.env` has `WEB_PORT=127.0.0.1:8088`; keep the default 80 for the clean lab machine.
- On the home PC (repo at `E:\Personal\devops-final`) port 80 is taken by Laravel Herd's nginx (the user's own; leave it), so its `.env` has `WEB_PORT=127.0.0.1:8088` too. Its Docker Desktop runs **cgroup v1** (WSL2 kernel 5.15): Kubernetes 1.35+ refuses cgroup v1 (`kubelet is configured to not run on a host using cgroup v1`) and, in the host cgroup namespace, systemd and the kubelet disagree on paths (`cgroup ["kubepods"] has some missing paths`). `ansible/tests/run.sh` handles both (`--cgroupns=private`; `fail-cgroupv1=false` only when `docker info` reports cgroup v1). Downloads from GitHub are slow there. Other projects' containers (e.g. `guestbook`) run on it; leave them.
- A `.gitignore` pattern can hide code: `kubeconfig*` hid `roles/kubeconfig/` while the rehearsal still passed (it reads the disk, not Git). After adding a folder, check `git status --untracked-files=all` lists every new file.
- Calling `python` in Git Bash on the home PC hangs (Windows Store alias); use the Docker image instead.
- WSL Ubuntu 24.04 on PC-01 has `make`, `docker` (same Docker Desktop daemon) and `curl`. Its default shell is zsh: `wsl.exe -- bash -c '...'` lets zsh expand `$(...)` first, in the wrong folder. Put longer commands in a script file and run `wsl.exe -d Ubuntu -- bash <file>`.
- For a clean-machine check, clone into WSL and run with `COMPOSE_PROJECT_NAME=<other>` and another `WEB_PORT`, so the running stack and its volume stay untouched; remove the test volume and clone afterwards.
- To rehearse server work locally (done for Q3; reuse for Q4's Ansible): an `ubuntu:24.04` container with `systemd systemd-sysv openssh-server ufw acl ...`, run `--privileged` with `/sbin/init`; UFW works in it. Copy `docker` and the compose plugin from `docker:29-cli`; mount the host socket at `/docker.sock` and `ln -s /docker.sock /run/docker.sock` after boot (systemd hides a mount under `/run`). It has no D-Bus, so run `systemctl status` as root. Use a second container on the same network as "the other machine". Pipe files between containers (`docker exec a cat f | docker exec -i b sh -c 'cat > f'`) rather than `docker cp` through Windows paths.
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

Q1 and Q2 are done; Q3's code is done and rehearsed (its screenshots are taken in the lab with `linux/evidence/commands.md`). Order agreed with the user on 12 Nov: write the infrastructure code on the user's own PC (Q4 Terraform and Ansible, Q5 Helm, Q6 monitoring, Q7 workflows), and use the AWS lab only to run it and take evidence (Q3 → Q8; PLAN.md sections 5 and 6).

**Q4, in steps (PROGRESS section 5):** 4.1 base (state bucket, S3 backend with lock, tags, budget) and 4.2 `modules/network` (VPC 10.0.0.0/16, public 10.0.0.0/24 + 10.0.1.0/24, private 10.0.10.0/24 + 10.0.11.0/24, IGW, one NAT Gateway, outputs `vpc_id`, `vpc_cidr`, `azs`, `public_subnet_ids`, `private_subnet_ids`) and 4.3 `modules/compute` (groups `nodes` with 8472/udp, 10250/tcp, 9100/tcp from itself and `control-plane` with 6443/tcp from `nodes`, no SSH, egress all; role with AmazonSSMManagedInstanceCore + AmazonEC2ContainerRegistryPullOnly; Ubuntu 24.04 control plane t3.medium and 2 workers t3.large round robin over the private subnets, no public IP, IMDSv2 hop 1, encrypted 30 GiB gp3, tags `role`; outputs instance ids, private IPs, `node_security_group_id`) and 4.4 `modules/alb` (internet-facing ALB in the public subnets; listeners 80 → prod NodePort 30080 and 8080 → dev NodePort 30081; instance target groups with the workers, health check `/ping` 200; ALB group 80/8080 in, egress only to `nodes` on the NodePorts; `nodes` accepts the NodePorts only from the ALB; no Route 53 without a domain; outputs `dns_name`, `urls`; root output `app_urls`) are done. Q5 must make Traefik answer `/ping` on the web entrypoint (or change `health_check_path`). 4.5 `modules/ecr` is done too (repositories `shoplite/web`, `shoplite/catalog-api`, `shoplite/order-worker` with `force_delete` only; outputs `repository_urls`, `repository_arns`, `registry`; root outputs `ecr_repository_urls`, `ecr_registry`), so all four modules the question names exist. 4.6 `terraform/q3-server` is done as well (the user chose a small VPC of its own: 10.1.0.0/16, one public subnet, IGW, no NAT; Ubuntu 24.04 t3.medium with a public IP, key pair from `TF_VAR_ssh_public_key`, 20 GiB encrypted disk, IMDSv2; 22, 80, 443 and 8000 only from `TF_VAR_admin_cidr` (/24 or narrower); backend key `q3-server/terraform.tfstate`; `linux/evidence/commands.md` sections 0.1 "Create the server" and "After grading"). 4.7 Ansible is split in three: 4.7a (base and `hardening` role) and 4.7b (`container_runtime`, `k3s_server`, `k3s_agent`, `kubeconfig`; rehearsed: three Ready nodes behind UFW, second run `changed=0`) are done. **4.7c (next): the lab connection: Ansible reaches the nodes with SSH over SSM (`ProxyCommand` with `aws ssm start-session --document-name AWS-StartSSHSession`), which needs a key pair on the nodes in the compute module (public key via `TF_VAR_`); the lab inventory and `vpc_cidr` from Terraform outputs; kubectl through an SSM port forward (`AWS-StartPortForwardingSession`, local 6443 → control plane 6443, matching the kubeconfig); kubelet's ECR credential provider using the node role.** Then 4.8 the lab procedure. For Q5: k3s's `servicelb` is on, so Traefik's Service must be `NodePort` (30080/30081), not `LoadBalancer`; check in the lab that ALB → NodePort passes UFW (routed allow). Lab limits are unknown until the PLAN Phase 3 preflight; keep alternatives (bastion, NAT instance) in mind. No Route 53 record unless the user has a domain.
