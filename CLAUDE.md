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

- `shoplite-app/` and `shoplite-gitops/` are the two repositories the question asks for. They live as subfolders here and will be split out later, so **every path inside them must be relative to that subfolder** (compose, Makefile, CI, Helm). The user's decision (14 Nov): keep working in this monorepo; split into `SaikatGeek/shoplite-app` (exists, holds only a placeholder `test.md`; the user chose on 15 Nov to replace it with a force push of the `git subtree split` history) and `SaikatGeek/shoplite-gitops` (not created yet) at the end, but **before the lab session that runs ArgoCD and the pipeline** (Q5 onward). The split's commands are section 0.1 of `docs/evidence/q5/commands.md`. Both repositories must be public, because ArgoCD reads them without credentials. After the split, a shoplite-app change is published by splitting again and pushing without `--force` (the split is deterministic, so it is a fast-forward). shoplite-gitops is changed in its own clone, because CI commits to it. Write code with those final URLs (`https://github.com/SaikatGeek/shoplite-app.git`, `https://github.com/SaikatGeek/shoplite-gitops.git`); GitHub Actions workflows go in `shoplite-app/.github/workflows/` (the split repo's root). Until the split, Actions and ArgoCD cannot run against GitHub: verify locally (ArgoCD in local k3s from a local git server with the URLs rewritten in the test).
- Root keeps course docs: `project.md`, `PLAN.md`, `PROGRESS.md`, `architecture-diagram.*`, `OFFICE-PC-GUIDE.md`.
- Target structure of both repos: `project.md` section 2.1 and `PLAN.md` section 3.
- Lab procedures, in English for the grader: `shoplite-app/docs/evidence/qN/commands.md` (the steps, what each should show, the screenshot names; the screenshots go in the same folder). Q3's is `linux/evidence/commands.md` because the question names that folder. Q4's (step 4.8) is checked without AWS: its tools block ran on a fresh `ubuntu:24.04`, every `--query` was evaluated with jmespath 1.0.1 on API-shaped samples, and every `aws` command was run without credentials (stopping only at `Unable to locate credentials` means the arguments are valid). Do the same for later ones.

Q5's procedure (step 5.4) was checked the same way, and two more:
- Its split ran in a container against bare stand-in repositories.
- Every bash block of its sections 5 and 6, taken verbatim from the markdown, ran from a stand-in lab machine (bash, kubectl, helm, curl). The cluster came from a copy of `scripts/tests/bootstrap-cluster.sh` with the cleanup trap and the self-heal step cut, where ArgoCD had installed Traefik, dev and prod. Remove its containers and network by hand afterwards.

Check later procedures with kubectl blocks the same way. No one-command lab script (the question does not ask for one; the user may ask later).

## Code conventions already in place (keep them)

- Python 3.12 on `python:3.12-alpine`. Dependencies pinned in each service's `requirements.txt` / `requirements-dev.txt`. To add one, install it in a throwaway `python:3.12-alpine` container, read the resolved version, pin it.
- Dockerfiles: API and worker have stages `builder` → `test` → `runtime`; the venv is created `--without-pip` and the base image's pip installs into it with `--python`. web has `test` → `runtime`. Runtime runs as uid/gid `10001` (web: the nginx image's own uid 101), has `HEALTHCHECK`, `.dockerignore`. Images must stay **under 150 MB**: unpacked now 64.6 MB web, 109.2 MB API, 88.0 MB worker (see the Docker 29 gotcha).
- web (`services/web/`): `nginxinc/nginx-unprivileged:1.30.6-alpine`, port 8080. `nginx/default.conf.template` is rendered by the image's entrypoint at start (`API_UPSTREAM`, DNS from resolv.conf via `NGINX_ENTRYPOINT_LOCAL_RESOLVERS=1`); `proxy_pass` uses a variable so nginx starts without the upstream. `/api/` strips the prefix and keeps the query; `Cache-Control: no-cache` on static files (the Q7 checkpoint changes `<title>`); `/healthz`; JSON access log with the five fields (level from status). Its "unit tests" are `tests/run.sh` (15 checks against a fake API) in the test stage.
- Compose (`docker-compose.yml`): exactly the five components. Only web is published (`${WEB_PORT:-80}:8080`; `WEB_PORT` may be `IP:PORT`); the API is reached through web's `/api/`. `depends_on` uses `service_healthy`. No trace backend in compose: spans are created (trace_id in logs) but exported only when `OTEL_EXPORTER_OTLP_ENDPOINT` is set, which happens in Kubernetes (Tempo).
- `scripts/smoke-test.sh` (POSIX sh, curl and sed, no jq) goes through web: up, `/api/readyz`, POST `/api/orders`, poll until `COMPLETED`. `Makefile` targets: `build up down test smoke`; `.env` is copied from `.env.example` on first use.
- `linux/` (Q3): `sshd_config` (Ubuntu 24.04 default plus PermitRootLogin, PasswordAuthentication, KbdInteractiveAuthentication and PubkeyAuthentication placed **before** the Include, because sshd keeps the first value), `systemd/shoplite-backup.{service,timer,sh}` (oneshot, Restart=on-failure 5 min, 3 starts/h; nightly 02:00; `docker compose -p shoplite exec -T postgres pg_dump` with the container's env, root-only `.sql` in `/var/backups/shoplite`), `firewall/ufw.sh`, and `evidence/commands.md` (English; the lab procedure, expected output and screenshot list). The Ansible `hardening` role in Q4 must apply the same files.
- `terraform/` (Q4): Terraform 1.17.2 (image `hashicorp/terraform:1.17.2`), AWS provider `~> 6.73` locked at 6.73.0 (commit `.terraform.lock.hcl`). `bootstrap/` creates the state bucket `shoplite-tfstate-<account>-<region>` (versioning, force_destroy, local state). The root uses a partial S3 backend (`key`, `encrypt`, `use_lockfile` in `backend.tf`; bucket and region via `-backend-config` at init), provider `default_tags` `project=shoplite`, and the USD 20 budget (`budget_alert_email` only via `TF_VAR_`, never in Git). Modules go in `terraform/modules/{network,compute,alb,ecr,github-oidc}` with their own `required_providers`. Every module and root config has `tests/*.tftest.hcl` with `mock_provider "aws"`, so `terraform test` runs without AWS; the real apply happens only in the lab. In tests use `command = apply` (mock apply, offline) to compare ids between resources, mock data sources with `mock_data` (e.g. `aws_availability_zones` names), and write explicitly in the code any value a test checks (the mock leaves provider defaults null). The provider still validates ARN arguments under a mock: give resources whose ARN is passed on (`aws_lb`, `aws_lb_target_group`) well-formed ARNs with `mock_resource`, and per-instance values with `override_resource { target = res["key"] }`. Module input validations also run in a mock apply, on the mock's values: the root test gives `aws_ecr_repository` a well-formed ARN for github-oidc's check. After a module change run `init -backend=false` in the root again. Q4 is split into steps 4.1–4.8 (PROGRESS section 5). The compute module puts key pair `<name>-nodes` (from `ssh_public_key`, `TF_VAR_` only) on every node for SSH over SSM; port 22 stays closed. Root outputs `ansible_inventory` (`templates/inventory.ini.tftpl`: nodes by instance id in the groups `site.yml` uses, user ubuntu, key `ssh_private_key_file`, ProxyCommand `aws ssm start-session ... AWS-StartSSHSession --parameters portNumber=%p`; written to the git-ignored `ansible/lab.ini`) and `kubectl_tunnel` (SSM port forward, local 6443 → control plane 6443).
- `terraform/modules/github-oidc` (Q7a, step 7.3), called from the root with the ECR module's ARNs:
  - IAM OIDC provider `https://token.actions.githubusercontent.com`, audience `sts.amazonaws.com`, no thumbprint (optional in provider 6.73; AWS checks GitHub's certificate itself).
  - Role `shoplite-github-ci`, trust `StringEquals` on `aud` and on `sub` = `repo:SaikatGeek/shoplite-app:ref:refs/heads/main` (no wildcard, so no PR or other branch).
  - Inline policy `ecr-push`: `ecr:GetAuthorizationToken` on `*`, and the six push actions from AWS's docs (`BatchCheckLayerAvailability`, `BatchGetImage`, `CompleteLayerUpload`, `InitiateLayerUpload`, `PutImage`, `UploadLayerPart`) on the given repository ARNs only.
  - Inputs validated (`owner/name`; ECR repository ARNs without wildcards). Root output `ci_role_arn` (the workflows' `role-to-assume`).
  - Its tests were checked by mutation (eight deliberate mistakes, each fails a run); do the same for later IAM changes.
  - The PR pipeline's Terraform plan (Q7b) will need a separate read-only role; never give PRs the push role.
- Main pipeline v1 (Q7a, step 7.4), `shoplite-app/.github/workflows/main.yml` (runs only after the split: GitHub reads workflows at a repository's root):
  - On push to main, one job (not a matrix: Trivy must later scan the very image that is pushed): tag `${GITHUB_SHA::7}`, `docker build --target runtime` of the three services.
  - Also `workflow_dispatch`, the Actions tab's "Run workflow" button (`2e538cc`; the user's choice on 15 Nov over an empty commit). A lab session starts with an empty ECR, so one run from main pushes main's newest images. From another branch nothing reaches AWS, because the role trusts only main. It goes in the README's deviation log.
  - Only `if: vars.LAB_ACTIVE == 'true'` (PLAN), the steps that need AWS: OIDC with `vars.AWS_ROLE_ARN` (region `vars.AWS_REGION || 'ap-southeast-1'`), ECR login and push, checkout of `SaikatGeek/shoplite-gitops` into `shoplite-gitops/` with `ssh-key: secrets.GITOPS_DEPLOY_KEY`, then `bash scripts/update-gitops.sh shoplite-gitops dev "$REGISTRY" "$TAG"`. Otherwise a notice; the run stays green.
  - `concurrency` group `main` without cancelling (push order); permissions `contents: read`, `id-token: write`; no kubectl.
  - Actions pinned by full commit SHA with the release in a comment (`# v7.0.1`): checkout v7.0.1, configure-aws-credentials v6.3.0, amazon-ecr-login v2.1.7 (the newest releases older than two weeks). To pick versions use git (`git ls-remote --tags`, `git fetch --depth=1 <repo> refs/tags/<tag>`): the GitHub REST API answered 403 (rate limit) from PC-01.
- Promote workflow (Q7, step 7.5, `7d4076a`; the user's choice on 15 Nov to build it before 5.4), `shoplite-app/.github/workflows/promote.yml`:
  - Only `workflow_dispatch`, no inputs, so it promotes exactly what dev runs.
  - Checks out shoplite-app and, with the deploy key, `shoplite-gitops/`. Step `id: promote` reads `.image.registry // ""` and `.image.tag // ""` from `envs/dev/values.yaml` with yq. It stops with `::error::dev has no image yet; run the main workflow first` when either is empty. Otherwise it runs `bash scripts/update-gitops.sh shoplite-gitops prod "$registry" "$tag"` and prints a `::notice::` to sync shoplite-prod in ArgoCD.
  - No AWS, no `LAB_ACTIVE`, no `id-token`; `contents: read`; `concurrency` group `promote`. Prod's chaos flags are never touched.
- `scripts/update-gitops.sh <checkout> <dev|prod> <registry> <tag>` (main for dev, promote for prod):
  - Each of three attempts fetches `+refs/heads/main:refs/remotes/origin/main` and resets to it.
  - Writes `.image.registry` and `.image.tag` with yq `strenv()`, so a tag such as `0123456` stays a string (`env()` would make it a number).
  - Commits only that file as `github-actions[bot]` and pushes `HEAD:main`. The body is `Built and pushed by <run URL> from <repo>@<sha>.` for dev and `Promoted from dev by <run URL>.` for prod. The same tag again commits nothing. Input validated.
- `scripts/tests/pipeline.sh` (with `runner.Dockerfile`: bash, git and yq like GitHub's ubuntu-24.04 runner, which has yq 4.54.3):
  - actionlint `rhysd/actionlint:1.7.12` (flag `-no-color`; it bundles shellcheck 0.11.0, used for the scripts too).
  - It covers every file in `.github/workflows/`.
  - main's triggers are exactly `push` to `main` and `workflow_dispatch`; promote's are only `workflow_dispatch`.
  - Each pin equals its release tag's commit; `with:` keys exist in that commit's `action.yml`, required inputs are given, and read outputs exist. actionlint does not know the newest releases' inputs.
  - `update-gitops.sh` against a bare copy of shoplite-gitops: first run, rerun, a concurrent commit plus a rejected first push via a `pre-receive` hook, an unquoted hand-written tag, bad input.
  - promote's own `run:` (read with yq) in a GitHub-like workspace: `scripts/` plus a clone in `shoplite-gitops/`. Checks: one bot commit with only prod's file, the tag a string, the chaos flag kept, the notice. With an empty dev it errors and commits nothing.
  - `helm template` with the written values, in dev and in prod.
  - Checked by mutation: nine mistakes, four on the triggers, six on promote. Each fails it, and the earlier ones were rerun after the loop over workflows. Extend it when the workflows grow.
- `ansible/` (Q4g): ansible-core 2.21.6 (`requirements.txt`; 2.22 needs Python 3.13, the lab's Ubuntu 24.04 has 3.12), ansible.posix 2.2.2 and community.general 14.0.1 (`requirements.yml`). Groups `control_plane`, `workers`, `k3s_cluster`. Role `hardening` applies Q3's 3.1, 3.2 and 3.4 with `linux/sshd_config` itself (`{{ playbook_dir }}/../linux/sshd_config`, validated with `sshd -t`) and UFW via `community.general.ufw` (22/80/443 like `linux/firewall/ufw.sh`; from `vpc_cidr` 8472/udp, 10250, 9100, and 6443 via `group_vars/control_plane.yml`; everything from the k3s pod and service CIDRs; routed allow). Role `container_runtime`: `overlay` and `br_netfilter` (modprobe only when the feature's path is missing), sysctls, and the k3s binary pinned in `group_vars/k3s_cluster.yml` (`k3s_version: v1.37.2+k3s1`) from the GitHub release with its sha256 (k3s's own containerd is the container runtime; no install script); `tasks/verify.yml` runs after k3s starts. `k3s_server` (config.yaml mode 0600 with Traefik disabled, systemd unit like the install script's, waits for `/readyz`, the token and node Ready), `k3s_agent` (reads `node-token` from the running server, never in Git), `kubeconfig` (k3s.yaml to `{{ playbook_dir }}/kubeconfig`, 0600, server `https://127.0.0.1:6443` for an SSM port forward). `k3s_kubelet_args` stays empty for EC2 (cgroup v2). `container_runtime` also installs kubelet's image credential provider (`ecr-credential-provider`, pinned `ecr_credential_provider_version: v1.37.0` from artifacts.k8s.io with its `.sha256`; config for `*.dkr.ecr.*.amazonaws.com` in `k3s_credential_provider_dir`), and both k3s config templates point kubelet at it; it gets ECR tokens with the node role, so no pull secret exists. When the k3s binary or the provider changes, `container_runtime` sets `container_runtime_restart_k3s` and the k3s roles notify their restart handler. Every play in `site.yml` has `any_errors_fatal`. `.gitignore` re-includes `roles/kubeconfig/` (its `kubeconfig*` rule hid the role). `ansible/tests/run.sh` rehearses on three systemd containers (subnet 10.99.0.0/24 plays the VPC; nodes get `--cgroupns=private` and volumes for `/var/lib/rancher/k3s` and `/var/lib/kubelet`) and fails unless the second run has `changed=0`, `tests/verify.yml` passes (it loads `../group_vars/k3s_cluster.yml` itself) and the cluster checks pass (three Ready nodes, CoreDNS, `kubectl top nodes` for every node, kubelet running `ecr-credential-provider` for an ECR image name on worker1, the fetched kubeconfig); extend it with every new role.
- `helm/shoplite` (Q5, PROGRESS section 6): one chart, one release per environment (`shoplite` prod, `shoplite-dev` dev). Fixed object names (`web`, `catalog-api`, `order-worker`, `postgres`, `redis`, ConfigMap `shoplite-config`), labels from `_helpers.tpl` (`app.kubernetes.io/name` = component; NetworkPolicies select on it). Images `[image.registry/]shoplite/<component>:<image.tag>` (defaults `""` and `local`; the lab's come from shoplite-gitops). Every pod non-root with the image's own uid (10001 apps, 101 web, 70 Postgres, 999/1000 Redis), seccomp RuntimeDefault, no privilege escalation, capabilities dropped; requests and limits on every container (dev lighter). DB credentials only from the existing Secret `database.existingSecret` (`shoplite-db`, keys `POSTGRES_USER`, `POSTGRES_PASSWORD`), created in the cluster, never by the chart. `checksum/config` on the catalog-api and order-worker pod templates. order-worker has no `replicas`: its HPA (`autoscaling/v2`, CPU 70% of the request) owns it, 1–4 in both environments (the user's choice: as the question says). catalog-api has a PDB `minAvailable: 1`. `templates/networkpolicy.yaml`: Ingress policies `postgres` and `redis` that admit only catalog-api and order-worker of the same release and namespace (no `namespaceSelector`) on the named port; nothing else (no default-deny, no egress rules; the question asks only this). `templates/ingress.yaml`: Middleware `strip-api` (`traefik.io/v1alpha1`) and two Ingresses (web `/`, catalog-api `/api` with the middleware), `ingressClassName: traefik`, entrypoint from `ingress.entrypoint` (prod `web`, dev `dev`). Postgres: StatefulSet + PVC, headless Service, seed `files/init.sql` via ConfigMap `postgres-init`, `PGDATA` subfolder.
- `shoplite-gitops` (Q7, PROGRESS section 7): `bootstrap/root-app.yaml` (app of apps over `apps/`, automated, prune, selfHeal; applied once at bootstrap); `apps/shoplite-dev.yaml` (namespace `shoplite-dev`, automated + prune + selfHeal) and `apps/shoplite-prod.yaml` (namespace `shoplite`, manual sync; self-heal is shown in dev), both multi-source: chart `helm/shoplite` from shoplite-app (`releaseName: shoplite`, `valueFiles: values-<env>.yaml, $gitops/envs/<env>/values.yaml`) plus this repo as `ref: gitops`; sync wave 1 (Traefik is wave 0) and `retry` with backoff. `envs/dev/values.yaml` (image registry and tag, written by CI) and `envs/prod/values.yaml` (promoted image, the four chaos flags all off) start empty, so the chart stops with `image.tag is required` until CI runs. Validate Applications with `ghcr.io/yannh/kubeconform:v0.8.0 -strict` and the Datree CRDs-catalog schema location; check value layering with `helm template -f values-<env>.yaml -f <envs file>`.
- Monitoring (Q6, PROGRESS section 6b): namespace `monitoring`, everything installed by ArgoCD.
  - Charts, picked on 16 Nov as the newest releases older than two weeks:
    - kube-prometheus-stack 92.17.0 (prometheus-community);
    - loki 20.2.1 and tempo 3.2.1 from **grafana-community** (grafana's own `loki` chart is now Grafana Enterprise Logs, and its `tempo` is deprecated);
    - alloy 1.15.0 (grafana).

    To list versions, download `https://<repo>.github.io/helm-charts/index.yaml` and read each entry's `created`.
  - Values live in shoplite-app `monitoring/stack/<chart>.yaml`. Each Application, shoplite-gitops `apps/<chart>.yaml`, is multi-source: the chart, plus shoplite-app as `ref: app` with `valueFiles: [$app/monitoring/stack/<chart>.yaml]`.
  - `kube-prometheus-stack.yaml` (6.1):
    - Sync and scope:
      - wave 0, because ShopLite's ServiceMonitors need its CRDs; ServerSideApply;
      - the k3s control plane is not scraped (controller-manager, scheduler, proxy, etcd);
      - `defaultRules.create: false` and `grafana.defaultDashboardsEnabled: false`: only ShopLite's five alerts and its own dashboard.
    - Prometheus:
      - every `*SelectorNilUsesHelmValues: false`;
      - `enableFeatures: [exemplar-storage]`;
      - retention 1d.
    - Grafana:
      - admin from the Secret `grafana-admin` (keys `admin-user`, `admin-password`);
      - `root_url` `.../grafana/` with `serve_from_sub_path`;
      - Ingress `/grafana` on Traefik's `web` entrypoint, without a host;
      - its ServiceMonitor path `/grafana/metrics`.
    - Requests and limits on everything.
    - Grafana's data sources (6.2), with fixed uids `prometheus`, `loki`, `tempo` (the links go by uid):
      - Prometheus: `grafana.sidecar.datasources.exemplarTraceIdDestinations` (label `trace_id` → tempo);
      - Loki (`additionalDataSources`, `http://loki.monitoring.svc.cluster.local:3100`): derived field `trace_id`, regex `"trace_id": *"([0-9a-f]{32})"` on the line, url `$${__value.raw}` (`$$`: Grafana's provisioning reads `$` as an environment variable) → tempo;
      - Tempo (`http://tempo.monitoring.svc.cluster.local:3200`): `tracesToLogsV2` → loki, tag `service.name` → label `service`, `filterByTraceID`, span time ±1m.
  - `loki.yaml` (6.2): monolithic, one replica, `auth_enabled: false`, replication 1, filesystem storage on the chart's 10Gi PVC, schema v13 tsdb. Off: gateway, memcached caches, canary, Helm test, rules sidecar. write, read and backend replicas 0 (the chart refuses to render otherwise). Service `loki:3100`.
  - `alloy.yaml` (6.2), a DaemonSet:
    - `discovery.kubernetes` finds the pods of its own node (the chart sets `HOSTNAME` to the node name);
    - labels namespace, pod and container;
    - `loki.source.kubernetes` reads logs through the API (GA in Alloy 1.21), so it mounts no host folder and runs as the image's uid 473;
    - `stage.json` and `stage.labels` make only `level` and `service` labels (trace_id stays in the line);
    - it pushes to `loki:3100/loki/api/v1/push`.

    Its RBAC is only pods (get, list, watch) and pods/log (get). The rules are split over `rbac.rules` and `rbac.clusterRules`, because an empty list breaks the chart's YAML. `crds.create: false`. Check the pipeline with `alloy fmt` from `grafana/alloy:v1.21.3`.
  - `tempo.yaml` (6.2): single binary, only requests and limits.
    - It keeps the chart's receivers (its Service template needs the Jaeger ones), among them OTLP/HTTP on 4318.
    - Traces stay on the pod's disk for 24 h.
    - The query API is on 3200 (`/api/v2/traces/<id>`); the image is distroless.
  - Loki, Tempo and Alloy are in sync wave 0 with kube-prometheus-stack, so they run before ShopLite.
  - The ShopLite chart's `config.otlpEndpoint` defaults to `http://tempo.monitoring.svc.cluster.local:4318` for both environments.
  - The dashboard (6.3), `monitoring/dashboards/golden-signals.json`:
    - title "ShopLite — Golden Signals" (em dash), uid `shoplite-golden-signals`;
    - custom variable `namespace` (label Environment: `shoplite` default, `shoplite-dev`);
    - data sources by uid (`prometheus`, `loki`).
    - The question's seven displays are eight panels:
      - Requests per second, per route;
      - HTTP 5xx error rate (`or ... * 0` shows 0 instead of no data);
      - Worker replicas (available, and the HPA's desired count);
      - Request latency per route: p50, p95, p99 (`exemplar: true` on p99);
      - Order queue depth (`max`, one value per catalog-api replica);
      - Orders created vs processed;
      - CPU usage per pod and Memory usage per pod (cAdvisor, `metrics_path="/metrics/cadvisor"`).

      Red threshold lines mark the alerts' limits: 5%, 1 s, 50.
    - Under a row "Investigation", the user's choice for Q8 (16 Nov):
      - a table of restarted containers with the last termination reason;
      - a Loki logs panel of `level="ERROR"`;
      - plus a dashboard annotation "Deploys", from changes in `kube_deployment_metadata_generation`.
    - The panel titles are checked by the rehearsal; rename them in both places.
  - `monitoring/kustomization.yaml`: `configMapGenerator` `shoplite-dashboards` (namespace monitoring, label `grafana_dashboard: "1"`, which kube-prometheus-stack's Grafana sidecar loads from every namespace, `disableNameSuffixHash`). Build it with `kubectl kustomize` from the k3s image (Kustomize v5.8.1). shoplite-gitops `apps/monitoring-config.yaml` (path `monitoring`, wave 1, automated) applies it; 6.4's PrometheusRule goes in the same Kustomization.
  - The chart's `templates/servicemonitor.yaml` scrapes `/metrics` every 15 s: catalog-api on port `http`, order-worker on port `metrics`. order-worker has a Service (port 8001) only for this.
  - Prometheus job names: `catalog-api`, `order-worker`, `node-exporter`, `kube-state-metrics`.
  - The Prometheus image is distroless (no shell, no wget). Query it from outside: the rehearsal curls its ClusterIP from the node's network.
- Cluster bootstrap (Q7 step 7.2, PROGRESS section 7): `scripts/bootstrap-cluster.sh` runs once per new cluster from the lab machine (needs `kubectl` and `helm`; kubeconfig through the `kubectl_tunnel` SSM port forward; shoplite-gitops next to shoplite-app, or `SHOPLITE_GITOPS_DIR`). It creates namespaces `shoplite` and `shoplite-dev` and a Secret `shoplite-db` in each (`POSTGRES_USER=shoplite`, random password; an existing Secret is kept, because Postgres keeps the password of its first start). It also creates namespace `monitoring` with the Secret `grafana-admin` (`admin-user=admin`, random `admin-password`). That Secret is kept if it exists too, because Grafana keeps the password of its first start. Then it installs ArgoCD from argo-helm chart `ARGOCD_CHART_VERSION=10.11.6` (ArgoCD v3.5.6) with `shoplite-gitops/bootstrap/argocd-values.yaml`, and applies `bootstrap/root-app.yaml`. It prints no secret. The values file's location was Claude's proposal from PLAN's example; the user may move it.
- What `argocd-values.yaml` sets:
  - Ingress `/argocd` (Prefix, no host, because the ALB's name changes every session) on Traefik's `web` entrypoint, with `server.insecure`, and `server.basehref` and `server.rootpath` set to `/argocd`. The admin password lives only in the cluster (`argocd-initial-admin-secret`).
  - `timeout.reconciliation: 60s`, jitter 0.
  - A Lua health check for `argoproj.io_Application` (ArgoCD's documented one), so root waits for Traefik (wave 0) to be Healthy before wave 1. Root does not wait for the last wave, so a manual prod never blocks root.
  - A Lua health check for `networking.k8s.io_Ingress` that is always Healthy. Traefik behind a NodePort never writes a load balancer status, so without it every app stays Progressing.
  - Dex and notifications off; requests and limits on every component.
- `scripts/tests/bootstrap-cluster.sh` rehearses 7.2 on a local `rancher/k3s:v1.37.2-k3s1`, without AWS or GitHub.
  - A test Git server (`gitserver.Dockerfile`: nginx, fcgiwrap, `git http-backend`) has fixed IP 172.30.0.10 on its own network 172.30.0.0/24, because k3s's CoreDNS cannot resolve Docker names. It holds bare repos created inside its container (never on the host: see the `%TEMP%` gotcha) from snapshots of the two folders. Snapshots use `git ls-files -co --exclude-standard`, so new files count.
  - Only the gitops snapshot changes: GitHub URLs point at the server, and `envs/*/values.yaml` get tag `local`.
  - The bootstrap runs twice in `tools.Dockerfile` (alpine/helm 4.3.1, bash, kubectl from the k3s image) on the node's network; the Secrets must stay unchanged.
  - Checks:
    - traefik, shoplite-dev and root Synced Healthy;
    - the ShopLite Applications created after the `middlewares.traefik.io` CRD;
    - prod OutOfSync with nothing deployed;
    - the `/argocd/` page (curl with `Accept: text/html`), API 401 without login, admin login, reconciliation 60s;
    - a manual prod sync through `POST /argocd/api/v1/applications/shoplite-prod/sync` (what the UI's button sends), then root Synced Healthy;
    - an order COMPLETED through each NodePort;
    - Q6.1:
      - kube-prometheus-stack Synced Healthy, and the ShopLite Applications created after the `servicemonitors.monitoring.coreos.com` CRD;
      - every Prometheus target up, including the required jobs in both namespaces;
      - the six metrics in prod;
      - a 32-hex `trace_id` exemplar on prod's `http_request_duration_seconds_bucket`;
      - Grafana at `/grafana/`: 401 without login, admin login with the Secret's password, a query through the data source uid `prometheus`;
    - Q6.2, everything through Grafana's data source proxy (`/grafana/api/datasources/proxy/uid/<uid>/...`):
      - loki, tempo and alloy Synced Healthy;
      - Loki has logs from argocd, kube-system, monitoring, shoplite, shoplite-dev and traefik;
      - its labels include namespace, pod, container, level and service, but not trace_id; services web, catalog-api and order-worker;
      - prod's "order created" line (LogQL `| json | order_id=...`) gives its trace_id through the Loki data source's own regex, and that data source links to uid tempo with `${__value.raw}`;
      - that trace in Tempo (`/api/v2/traces/<id>`) has the API → queue → worker → database spans. The consumer's parent is the producer, and `deployment.environment` is prod;
      - the Tempo data source's logs link (loki, `service.name=service`, by trace id) finds the worker's "order completed" line;
      - the Prometheus data source's exemplar link, and the exemplar's trace in Tempo;
    - Q6.3:
      - monitoring-config Synced Healthy;
      - Grafana serves uid `shoplite-golden-signals` with the exact title and the eight required panel titles, and exemplars on the latency panel;
      - every panel query and the Deploys annotation run for prod through Grafana's data sources (`$namespace` → shoplite, `$__rate_interval` → 5m) and succeed;
      - the eight required panels return data;
      - in dev, an unreadable queue message (`redis-cli LPUSH orders:pending 'not an order'`) and a stopped worker process (`kill 1`) show in "Recent error logs" and "Restarted containers" (with the reason);
      - right after the self-heal step's `kubectl scale`, the Deploys annotation marks prod's web (it shows within about 20 s; its window is 2 minutes);
    - self-heal reverts a `kubectl scale` in dev, while prod keeps it and shows OutOfSync.
  - The monitoring charts' images are preloaded by `stack_images` (chart and values from the Application); images pinned by digest are left to k3s.
  - The test k3s runs `mount --make-rshared /` after it is Ready. node-exporter mounts `/` with HostToContainer propagation, which a container's private `/` refuses.
  - About 13 minutes on PC-01 with the whole monitoring stack; more on the home PC.
  - Passed in full on PC-01 on 15 Nov, first try (step 7.2 done), with the metrics stack on 16 Nov (step 6.1), and with logs and traces on 16 Nov (step 6.2).
  - To debug against a live cluster: run a copy with the `trap ... EXIT` line removed, placed in `scripts/tests/` (the script `cd`s from its own folder). Remove its containers, network and `/tmp/tmp.*` work folder by hand afterwards, and delete the copy.
- Traefik (Q5d) lives in **shoplite-gitops** `apps/traefik.yaml` (the user's choice, per PLAN): an ArgoCD Application with Traefik's chart 42.2.0 (Traefik v3.7.16) and inline `valuesObject`: NodePort Service, entrypoint `web` → 30080 (prod, ALB 80) and `dev` (port 8001, exposed 8080) → 30081 (dev, ALB 8080), no websecure, `/ping` on web and dev through the chart's `ingressRoute.healthcheck` (the ALB health check), requests and limits, `ServerSideApply=true`. Traefik's Middleware CRD must exist before the shoplite chart is applied (sync Traefik first in Q7).
- `helm/tests/run.sh` rehearses on a local `rancher/k3s:v1.37.2-k3s1` container (images loaded with `docker save | ctr import`; Helm `alpine/helm:4.3.1` and `curl` from the web image on the k3s container's network; `fail-cgroupv1=false` on cgroup v1 hosts). It installs Traefik exactly as `../shoplite-gitops/apps/traefik.yaml` says (read with `mikefarah/yq:4.54.1`; `SHOPLITE_GITOPS_DIR` overrides the path), and the ServiceMonitor CRD from the kube-prometheus-stack chart `apps/kube-prometheus-stack.yaml` pins (`charts/crds/crds/crd-servicemonitors.yaml` of the pulled chart). It then lints, dry-runs the prod manifests server-side, installs dev (`shoplite-dev`) and prod (`shoplite`), then checks ready pods, non-root uids, requests/limits, the seed, orders to `COMPLETED` (through web's proxy and through NodePorts 30080/30081, each landing in its own environment's database), `/ping` 200 on both NodePorts, NetworkPolicy (`nc -z` from the pods: catalog-api and order-worker reach `postgres:5432` and `redis:6379`, web does not, dev does not reach prod's), a setting change rolling only catalog-api and order-worker (Deployment `generation`), the HPA scaling out under 400 orders, and `kubectl drain` evicting one catalog-api pod per environment while the PDB refuses the second. About 10 minutes (20 on 16 Nov, step 6.2); extend it with every chart step.
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

The AWS provider is about 150 MB; a Docker volume as plugin cache saves downloading it for every folder (fill it once by copying an existing `terraform/<dir>/.terraform/providers/.` into the volume):

```bash
TF="docker run --rm -v $(pwd -W)/terraform:/tf -v shoplite-tf-cache:/cache -e TF_PLUGIN_CACHE_DIR=/cache -w /tf hashicorp/terraform:1.17.2"
MSYS_NO_PATHCONV=1 $TF fmt -check -recursive
MSYS_NO_PATHCONV=1 $TF -chdir=bootstrap init -backend=false && MSYS_NO_PATHCONV=1 $TF -chdir=bootstrap test
MSYS_NO_PATHCONV=1 $TF init -backend=false && MSYS_NO_PATHCONV=1 $TF validate && MSYS_NO_PATHCONV=1 $TF test
```

Helm chart rehearsal (Docker and internet; 10–20 minutes; cleans up after itself; needs `../shoplite-gitops`): `bash helm/tests/run.sh`. GitOps rehearsal (Docker and internet; with the monitoring stack about 13 minutes on PC-01, more on the home PC; cleans up after itself; needs `../shoplite-gitops`): `bash scripts/tests/bootstrap-cluster.sh`. Pipeline rehearsal (Docker and internet; about 20 seconds; cleans up after itself; needs `../shoplite-gitops`): `bash scripts/tests/pipeline.sh`. Ansible rehearsal (Docker and internet; 5–10 minutes, mostly the k3s download; cleans up after itself): `bash ansible/tests/run.sh`. Run it in the background and redirect its output to a file; the playbook's own log goes to a temp folder (`/tmp/tmp.*/run1.log`).

On PC-01 real `make` runs in WSL Ubuntu: `wsl.exe -d Ubuntu --cd /mnt/e/devops-final/shoplite-app -- make up` (see the WSL gotcha for anything longer).

The page is at `http://127.0.0.1:<WEB_PORT>` (PC-01: http://127.0.0.1:8088); the API through it at `/api/...` (`/api/readyz`, `/api/products`, `/api/metrics`). The worker's `/healthz` and `/metrics` are on port 8001 inside its container only (`docker compose exec order-worker wget -qO- http://127.0.0.1:8001/metrics`).

## Gotchas found so far

- Windows Git Bash rewrites absolute paths and `X:\...` paths in arguments (`/opt/venv/...` becomes `C:/Program Files/Git/...`). Prefix such `docker run`, `docker exec` and `wsl.exe` commands with `MSYS_NO_PATHCONV=1`.
- On PC-01 (the Windows machine with the repo at `E:\devops-final`) port 80 is taken by `httpd` and 8080 by a `php` process (the user's own; leave them). Its `.env` has `WEB_PORT=127.0.0.1:8088`; keep the default 80 for the clean lab machine.
- On the home PC (repo at `E:\Personal\devops-final`) port 80 is taken by Laravel Herd's nginx (the user's own; leave it), so its `.env` has `WEB_PORT=127.0.0.1:8088` too. Its Docker Desktop runs **cgroup v1** (WSL2 kernel 5.15): Kubernetes 1.35+ refuses cgroup v1 (`kubelet is configured to not run on a host using cgroup v1`) and, in the host cgroup namespace, systemd and the kubelet disagree on paths (`cgroup ["kubepods"] has some missing paths`). `ansible/tests/run.sh` handles both (`--cgroupns=private`; `fail-cgroupv1=false` only when `docker info` reports cgroup v1). Downloads from GitHub are slow there. Other projects' containers (e.g. `guestbook`) run on it; leave them.
- A `.gitignore` pattern can hide code: `kubeconfig*` hid `roles/kubeconfig/` while the rehearsal still passed (it reads the disk, not Git). After adding a folder, check `git status --untracked-files=all` lists every new file.
- Calling `python` in Git Bash on the home PC hangs (Windows Store alias); use the Docker image instead.
- The home PC's line sometimes cuts downloads (curl exit 18, partial file): give manual curl `--retry 5 --retry-all-errors`; Ansible's downloads retry already.
- `terraform console` in the root wants the S3 backend initialised; render templates by running console in `terraform/templates` instead.
- Claude Code's safety check blocks a command that contains both an `sh -c` script and `rm`. Keep cleanup (`docker rm -f -v <names>`, `docker network rm`, `docker volume rm`) in its own command.
- AWS CLI v1 (e.g. `pip install awscli`) ignores `AWS_REGION` and reads only `AWS_DEFAULT_REGION`; v2 reads both. Lab procedures export both.
- SSH over SSM can be rehearsed without AWS: a stand-in `aws` script that reads `--target` and `portNumber=` and runs `exec nc <target> <port>`, on the controller's PATH, with the rendered inventory pointing `ansible_host` at test containers.
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
- A script that exports `MSYS_NO_PATHCONV=1` (for docker) also stops path conversion for Windows' `git.exe`: `git -C /tmp/...` fails with `cannot change to`. Run git from inside the folder with relative paths, or inside a container.
- If Docker Desktop is not running (`failed to connect to the docker API at npipe:////./pipe/dockerDesktopLinuxEngine`), start it from PowerShell with `Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"`. Then wait until `docker info` answers (about a minute). Starting it from a Bash background process did not work.
- After an unclean shutdown, Docker Desktop on PC-01 crashed at start (16 Nov).
  - Its log `%LOCALAPPDATA%\Docker\log\host\com.docker.backend.exe.log` said `backend crashed ... initializing Inference manager: ... remove ...\Docker\run\dockerInference: The file cannot be accessed by the system`, and next time the same for `docker-secrets-engine\engine.sock`.
  - These are AF_UNIX socket files that neither Docker, `Remove-Item` nor `del` can delete.
  - Fix: rename the folders that hold them (`%LOCALAPPDATA%\Docker\run`, `%LOCALAPPDATA%\docker-secrets-engine`) to `*.stale-<date>`, then start Docker again. It makes new ones. The stale folders can be deleted after a reboot.
- On the home PC something deletes empty folders under `%TEMP%` (seen 15 Nov, 02:05). A Git repo there lost its empty `refs/` and stopped being a repository. Keep test repositories inside containers.
- Right after Traefik's first sync, ArgoCD shows a ComparisonError for 30–45 s: `unable to resolve parseableType for GroupVersionKind: traefik.io/v1alpha1, Kind=IngressRoute`. The ServerSideApply diff needs the new CRD's schema. It clears by itself; meanwhile the app reads `Unknown Healthy`.
- ArgoCD 3 does not keep per-resource health in the Application CR (`.status.resources[*].health` is empty). To see which resource is not Healthy, ask the API: `GET /argocd/api/v1/applications/<name>/resource-tree`, with a token from `POST /argocd/api/v1/session` (admin).
- curl gets ArgoCD's raw `index.html` with `<base href="/">`. The `/argocd` base is written only when the request sends `Accept: text/html`.

## Next work (details in PROGRESS.md)

Q1 and Q2 are done; Q3's code is done and rehearsed (its screenshots are taken in the lab with `linux/evidence/commands.md`). Order agreed with the user on 12 Nov: write the infrastructure code on the user's own PC (Q4 Terraform and Ansible, Q5 Helm, Q6 monitoring, Q7 workflows), and use the AWS lab only to run it and take evidence (Q3 → Q8; PLAN.md sections 5 and 6).

**Q4, in steps (PROGRESS section 5):** 4.1 base (state bucket, S3 backend with lock, tags, budget) and 4.2 `modules/network` (VPC 10.0.0.0/16, public 10.0.0.0/24 + 10.0.1.0/24, private 10.0.10.0/24 + 10.0.11.0/24, IGW, one NAT Gateway, outputs `vpc_id`, `vpc_cidr`, `azs`, `public_subnet_ids`, `private_subnet_ids`) and 4.3 `modules/compute` (groups `nodes` with 8472/udp, 10250/tcp, 9100/tcp from itself and `control-plane` with 6443/tcp from `nodes`, no SSH, egress all; role with AmazonSSMManagedInstanceCore + AmazonEC2ContainerRegistryPullOnly; Ubuntu 24.04 control plane t3.medium and 2 workers t3.large round robin over the private subnets, no public IP, IMDSv2 hop 1, encrypted 30 GiB gp3, tags `role`; outputs instance ids, private IPs, `node_security_group_id`) and 4.4 `modules/alb` (internet-facing ALB in the public subnets; listeners 80 → prod NodePort 30080 and 8080 → dev NodePort 30081; instance target groups with the workers, health check `/ping` 200; ALB group 80/8080 in, egress only to `nodes` on the NodePorts; `nodes` accepts the NodePorts only from the ALB; no Route 53 without a domain; outputs `dns_name`, `urls`; root output `app_urls`) are done. Q5 must make Traefik answer `/ping` on the web entrypoint (or change `health_check_path`). 4.5 `modules/ecr` is done too (repositories `shoplite/web`, `shoplite/catalog-api`, `shoplite/order-worker` with `force_delete` only; outputs `repository_urls`, `repository_arns`, `registry`; root outputs `ecr_repository_urls`, `ecr_registry`), so all four modules the question names exist. 4.6 `terraform/q3-server` is done as well (the user chose a small VPC of its own: 10.1.0.0/16, one public subnet, IGW, no NAT; Ubuntu 24.04 t3.medium with a public IP, key pair from `TF_VAR_ssh_public_key`, 20 GiB encrypted disk, IMDSv2; 22, 80, 443 and 8000 only from `TF_VAR_admin_cidr` (/24 or narrower); backend key `q3-server/terraform.tfstate`; `linux/evidence/commands.md` sections 0.1 "Create the server" and "After grading"). 4.7 Ansible is split in three: 4.7a (base and `hardening` role) and 4.7b (`container_runtime`, `k3s_server`, `k3s_agent`, `kubeconfig`; rehearsed: three Ready nodes behind UFW, second run `changed=0`) are done. 4.7c (the lab connection: node key pair, `ansible_inventory` and `kubectl_tunnel` outputs, kubelet's ECR credential provider) and 4.8 (`docs/evidence/q4/commands.md`, the lab procedure and evidence list) are done too: Q4's code is complete; what remains of Q4 is running it in the lab. Lab limits are unknown until the PLAN Phase 3 preflight (the procedure's 0.4 has the fallbacks). No Route 53 record unless the user has a domain.

**Q5, in steps (PROGRESS section 6):** 5.1–5.4 are done. Q5's code and its lab procedure `docs/evidence/q5/commands.md` (`04305e8`) are complete. In the lab, everything is installed by ArgoCD and images reach ECR through the pipeline (the user chose PLAN's way, 14 Nov).

The procedure:
- Once: the split (section 0.1) and the GitHub settings (0.2: the deploy key and its secret, `AWS_REGION` if needed).
- Every session, in order:
  1. Q4's procedure 0.2–3, then Helm 4.3.1;
  2. the variables `AWS_ROLE_ARN` and `LAB_ACTIVE=true`;
  3. main's "Run workflow";
  4. `scripts/bootstrap-cluster.sh`;
  5. promote's "Run workflow", then prod's manual sync in ArgoCD (REFRESH → SYNC);
  6. the evidence for 5a–5e and the checkpoint (19 screenshots, video V2);
  7. `LAB_ACTIVE=false` and Q4's destroy at the end.

Promote runs every session: only main's newest images are in the fresh ECR. Check in the lab that ALB → NodePort passes UFW (routed allow).

**Q7's GitOps foundation, in steps (PROGRESS section 7):** 7.1 (shoplite-gitops: root app, dev and prod Applications, `envs` values) and 7.2 (cluster bootstrap, ArgoCD; the GitOps rehearsal passed in full on PC-01, 15 Nov) are done.

7.3 (Terraform `modules/github-oidc`: the CI role, push to the three ECR repositories only, `ac8e1b3`), 7.4 (main pipeline v1, `e23bf34`, with its "Run workflow" button `2e538cc`) and 7.5 (`promote.yml`: dev's image to prod through Git, `7d4076a`) are done too. The two workflows are rehearsed locally; their first real runs come after the split.

At the split, `SaikatGeek/shoplite-app`'s placeholder `test.md` is replaced: the user chose a force push of the `git subtree split` history (15 Nov).

**Q6, in steps (PROGRESS section 6b; Q6 before the rest of Q7 was Claude's advice, and on 16 Nov the user said to go on):**
- 6.1 is done (`cb6830f`; both rehearsals passed on PC-01, 16 Nov): metrics through kube-prometheus-stack, ServiceMonitors, exemplar storage, Grafana at `/grafana`.
- 6.2 is done (`289ea11`; the GitOps, chart and pipeline rehearsals passed on PC-01, 16 Nov): Loki, Alloy with JSON parsing, Tempo with OTLP. In Grafana: log → trace, trace → log, exemplar → trace.
- 6.3 is pushed (`cadd840`) but not yet done: its first version passed the GitOps rehearsal on PC-01 (16 Nov); the fix (`group_left`) and the three new checks were tried by hand on that cluster, but the full run of the last version did not finish before the user left the office. **First thing on the home PC: run `bash scripts/tests/bootstrap-cluster.sh`; if it passes, mark 6.3 ✅ in PROGRESS (table and section 13) and here.** What it is: the "ShopLite — Golden Signals" dashboard as JSON in Git, through Kustomize and ArgoCD; eight panels for the question plus, the user's choice, restarts, error logs and deploy marks for Q8.
- 6.4: five alerts, runbooks, Alertmanager → Slack. It needs the user's Slack incoming webhook URL, which goes in a Secret, never in Git.
- 6.5: the lab procedure `docs/evidence/q6/commands.md`.

Then the rest of Q7, on the user's own PC:
  - lint (Hadolint, `helm lint`), tests and the Trivy gate in main;
  - `pr.yml`;
  - `terraform-plan.yml`, with a separate read-only role;
  - self-heal evidence.

Then the repository split and the lab sessions Q3 → Q8.
