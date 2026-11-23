# Question 5: commands and evidence

ShopLite runs in the namespace `shoplite` (prod, the ALB's port 80) from the single Helm chart
`helm/shoplite` with `values-prod.yaml`. The same chart with `values-dev.yaml` runs dev in
`shoplite-dev` (the ALB's port 8080). Nothing is installed by hand:

- `scripts/bootstrap-cluster.sh` installs ArgoCD.
- ArgoCD installs Traefik and both ShopLite releases from `shoplite-gitops`.
- The images reach ECR only through the main pipeline (question 7).

Everything runs in the **lab terminal**, from the `shoplite-app` folder of the clone, unless a
step says otherwise; the GitHub and ArgoCD steps happen in the browser. The screenshots for
each part are listed at its end; the files go in this folder.

> **Cost:** this builds on question 4's infrastructure, which is billed by the hour. Take the
> evidence in the same session, and end it with [After the session](#after-the-session).

Roughly: question 4's part 20–30 minutes; the main pipeline about 5 minutes (it runs while the
cluster is bootstrapped); the bootstrap 5–10 minutes; promotion and prod's sync 2–3 minutes.

## 0. Once, before the first session

### 0.1 The two repositories

The question asks for two repositories. They were developed as the folders `shoplite-app/`
and `shoplite-gitops/` of one repository, `SaikatGeek/devops-final`, and are split from it
with their history. ArgoCD reads both over HTTPS without credentials, so both are public, with
`main` as the default branch (Settings → General).

`publish-repos.sh`, at the root of `devops-final`, does the split:

- `git subtree split` gives each folder's history as a branch of its own, `split/<folder>`.
- The commit messages are cleaned; authors, committers and dates are kept, so every run gives
  the same commits.
- `bash publish-repos.sh push` also pushes shoplite-app, as a fast-forward.

**Done on 17 Nov:**

1. `SaikatGeek/shoplite-gitops` was created on GitHub, empty and public.
2. In `devops-final`:

   ```bash
   bash publish-repos.sh
   git push --force-with-lease=main:cd159531a123d88c3ec69fa00ca163bf6fcbe8ab https://github.com/SaikatGeek/shoplite-app.git split/shoplite-app:main
   git push https://github.com/SaikatGeek/shoplite-gitops.git split/shoplite-gitops:main
   ```

   The force push replaced shoplite-app's placeholder commit (`test.md`), and only that commit.
3. Each `main` on GitHub is its split branch (the same commit, twice):

   ```bash
   git rev-parse split/shoplite-app split/shoplite-gitops
   git ls-remote https://github.com/SaikatGeek/shoplite-app.git refs/heads/main
   git ls-remote https://github.com/SaikatGeek/shoplite-gitops.git refs/heads/main
   ```

The push to shoplite-app started its first main pipeline run. Until `LAB_ACTIVE` is set it only
lints, tests, builds and scans the images, and stays green.

**To publish a later change** to shoplite-app, commit it in `devops-final` and run, from its
root:

```bash
bash publish-repos.sh push
```

Change shoplite-gitops in its own clone, or in GitHub's web editor, from now on: CI commits
to it, so `publish-repos.sh` never pushes it.

### 0.2 GitHub settings

The pipeline writes to shoplite-gitops with a deploy key: it can write to that one repository
only, and is tied to no one's account. (`GITHUB_TOKEN` cannot push to another repository.)
Make the key on any machine with `ssh-keygen`:

```bash
ssh-keygen -t ed25519 -N '' -C shoplite-app-ci -f shoplite-gitops-deploy
cat shoplite-gitops-deploy.pub
```

1. **shoplite-gitops** → Settings → Deploy keys → Add deploy key: title `shoplite-app CI`, key
   the line `cat` printed, and tick **Allow write access**.
2. **shoplite-app** → Settings → Secrets and variables → Actions → Secrets → New repository
   secret: name `GITOPS_DEPLOY_KEY`, value the whole private key file
   (`cat shoplite-gitops-deploy`, from `-----BEGIN` to the `-----END` line).
3. Delete both files. The private key now exists only in the secret:

   ```bash
   rm shoplite-gitops-deploy shoplite-gitops-deploy.pub
   ```

4. Only if the lab's region is not `ap-southeast-1`: **shoplite-app** → Settings → Secrets and
   variables → Actions → Variables → New repository variable `AWS_REGION`, set to the region.

Screenshot `01-github-settings.png`: the deploy key with write access on shoplite-gitops, and
the secret `GITOPS_DEPLOY_KEY` on shoplite-app (GitHub never shows a secret's value).

### 0.3 A Slack incoming webhook (for question 6's alerts)

Alertmanager sends the alerts to a Slack channel through an incoming webhook. In Slack: Apps →
create an app for your workspace → Incoming Webhooks → on → Add New Webhook to Workspace →
pick the channel → copy the URL (`https://hooks.slack.com/services/...`). Keep it like a
password: the bootstrap (section 3) asks for it and stores it only in the cluster.

## 1. Every session: the cluster and the GitHub variables

1. Clone both repositories side by side (`scripts/bootstrap-cluster.sh` reads
   `../shoplite-gitops`):

   ```bash
   cd ~
   git clone https://github.com/SaikatGeek/shoplite-app.git
   git clone https://github.com/SaikatGeek/shoplite-gitops.git
   cd shoplite-app
   ```

   Then follow question 4's procedure ([`../q4/commands.md`](../q4/commands.md)) from 0.2
   to 3: tools, settings, Terraform, Ansible, and the kubectl tunnel in a second terminal.
2. Helm, for the bootstrap and `helm lint`, checksum checked:

   ```bash
   curl -fsSL --retry 5 --retry-all-errors -o ~/tools/helm.tar.gz https://get.helm.sh/helm-v4.3.1-linux-amd64.tar.gz
   echo "$(curl -fsSL --retry 5 https://get.helm.sh/helm-v4.3.1-linux-amd64.tar.gz.sha256sum | cut -d' ' -f1)  $HOME/tools/helm.tar.gz" | sha256sum --check
   tar -xzf ~/tools/helm.tar.gz -C ~/tools linux-amd64/helm && sudo install ~/tools/linux-amd64/helm /usr/local/bin/
   helm version
   ```

3. kubectl's settings (question 4, section 3), the ALB's address, and the CI role:

   ```bash
   export KUBECONFIG=$PWD/ansible/kubeconfig
   ALB=http://$(aws elbv2 describe-load-balancers --names shoplite --query 'LoadBalancers[0].DNSName' --output text)
   echo "prod: $ALB  dev: $ALB:8080  ArgoCD: $ALB/argocd/"
   terraform -chdir=terraform output -raw ci_role_arn; echo
   ```

   A new terminal needs these again (`KUBECONFIG` comes with `source ~/shoplite.env`).
4. **shoplite-app** → Settings → Secrets and variables → Actions → Variables: set
   `AWS_ROLE_ARN` to the role's ARN that was just printed, and `LAB_ACTIVE` to `true`. Set
   question 7's per-session variables now too (`SSH_PUBLIC_KEY`, `ADMIN_CIDR`,
   `AWS_PLAN_ROLE_ARN`; [`../q7/commands.md`](../q7/commands.md), section 0).

## 2. The images: the main pipeline

ECR is new in every session, so the pipeline runs once at the start. **shoplite-app** →
Actions → main → Run workflow (branch `main`) → Run workflow.

The run builds the three images and tags them with the short commit SHA. It pushes them to
ECR through OIDC, and commits the tag to `envs/dev/values.yaml` in shoplite-gitops. Start
section 3 while it runs.

When the run is green:

```bash
for service in web catalog-api order-worker; do
  aws ecr describe-images --repository-name "shoplite/$service" \
    --query 'imageDetails[].[repositoryName,imageTags[0],imagePushedAt]' --output text
done
git -C ../shoplite-gitops pull -q
git -C ../shoplite-gitops log -3 --format='%h %an %ar: %s'
cat ../shoplite-gitops/envs/dev/values.yaml
```

The images carry the short SHA of shoplite-app's `main`. The newest shoplite-gitops commit is
`dev: images <sha>` by `github-actions[bot]`. If dev had that tag already from an earlier
session, the run says `nothing to commit` instead.

Screenshots: `02-main-run.png` (the green run and its steps), `03-ecr-images.png`.

## 3. Bootstrap the cluster

Once per cluster, the script creates:

- namespaces `shoplite` and `shoplite-dev`;
- the database Secret in each, with a random password made in the cluster (never in Git);
- namespace `monitoring` and Grafana's admin Secret, also with a random password (question 6);
- Alertmanager's Secret `alertmanager-slack`, with the Slack webhook from section 0.3
  (question 6);
- ArgoCD (chart 10.11.6, ArgoCD v3.5.6);
- the root Application.

From then on ArgoCD builds everything from Git: Traefik and the monitoring stack first (sync
wave 0: kube-prometheus-stack, Loki, Tempo, Alloy), then the ShopLite Applications and the
dashboard and alerts (wave 1).

Paste the webhook URL at the prompt; `read -s` keeps it off the screen and out of the shell's
history:

```bash
read -rsp 'Slack webhook URL: ' SLACK_WEBHOOK_URL; echo
export SLACK_WEBHOOK_URL
bash scripts/bootstrap-cluster.sh
watch -n 5 kubectl -n argocd get applications
```

Wait until `traefik`, `kube-prometheus-stack`, `loki`, `tempo`, `alloy`, `shoplite-dev` and
`monitoring-config` are `Synced` and `Healthy`: 5–10 minutes, and dev needs the tag from
section 2. Ctrl+C ends `watch`.

`shoplite-prod` waits for a manual sync. It shows `OutOfSync`, or, before the first promotion
ever, a ComparisonError `image.tag is required`, because prod's values in Git are still
empty.

Right after Traefik's first sync, ArgoCD may show a ComparisonError about `IngressRoute` for
30–45 s. It clears on its own.

```bash
kubectl -n argocd get applications
kubectl -n shoplite-dev get pods
curl -s "$ALB:8080/api/readyz"; echo
```

The ALB's targets are healthy now that Traefik answers `/ping`: take question 4's
`10-target-health.png` (its section 4d).

Screenshots:
- `04-bootstrap.png`: the script's output (the namespaces, `Secret shoplite-db created (random
  password)`, ArgoCD's deployments, the root Application).
- `05-argocd-applications.png`: traefik, the monitoring stack and shoplite-dev `Synced
  Healthy`, prod waiting.

## 4. Prod: promote, then sync by hand

1. **shoplite-app** → Actions → promote → Run workflow (branch `main`) → Run workflow. It
   commits the image dev runs to `envs/prod/values.yaml` in shoplite-gitops, and ends with a
   notice to sync prod:

   ```bash
   git -C ../shoplite-gitops pull -q
   git -C ../shoplite-gitops log -3 --format='%h %an %ar: %s'
   cat ../shoplite-gitops/envs/prod/values.yaml
   ```

2. Open ArgoCD at `$ALB/argocd/` in the browser and log in as `admin`. The command below
   prints the password; keep it out of the screenshots.

   ```bash
   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo
   ```

3. In ArgoCD: Applications → `shoplite-prod` → REFRESH (it reads the promotion's commit) →
   SYNC → SYNCHRONIZE. Wait for `Synced` and `Healthy`: about a minute, because PostgreSQL
   starts and seeds the products first.

   ```bash
   kubectl -n argocd get applications
   kubectl -n shoplite get pods
   ```

Screenshots:
- `06-promote-run.png`: the green promote run with its notice, and the `prod: images <sha>`
  commit.
- `07-argocd-prod-synced.png`: shoplite-prod's resource tree in ArgoCD, `Synced` and `Healthy`.
- `08-applications-synced.png`: every Application `Synced Healthy`, and the pods of
  `shoplite` `Running`.

## 5. Evidence for each part

### 5a Workloads and security

All five workloads of 5.1, in the namespace `shoplite`:

```bash
kubectl -n shoplite get deployments,statefulsets,services,ingresses,pdb,hpa,pvc
```

| Component | What the listing shows |
|---|---|
| `web` | Deployment, 2/2 |
| `catalog-api` | Deployment, 2/2 |
| `order-worker` | Deployment; its HPA (1–4) sets the replica count |
| `postgres` | StatefulSet, 1/1, its PVC `Bound` |
| `redis` | Deployment, 1/1, a `ClusterIP` Service only |
| Ingresses | `/` to web, `/api` to catalog-api |

Probes, the PDB, the HPA, and the grace period:

```bash
kubectl -n shoplite get deployment catalog-api -o jsonpath='liveness {.spec.template.spec.containers[0].livenessProbe.httpGet.path}, readiness {.spec.template.spec.containers[0].readinessProbe.httpGet.path}{"\n"}'
kubectl -n shoplite get pdb catalog-api
kubectl -n shoplite get hpa order-worker
kubectl -n shoplite get deployment order-worker -o jsonpath='terminationGracePeriodSeconds: {.spec.template.spec.terminationGracePeriodSeconds}{"\n"}'
```

A minute after the pods start, metrics-server has a sample. The HPA's `TARGETS` then shows the
CPU use against its 70% target, e.g. `cpu: 2%/70%`.

PostgreSQL's data volume and the seeded products:

```bash
kubectl -n shoplite get pvc
kubectl -n shoplite exec postgres-0 -- sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT count(*) AS products FROM products"'
```

Requests and limits on every pod, and no container running as root:

```bash
kubectl -n shoplite get pods -o custom-columns='POD:.metadata.name,CPU_REQUEST:.spec.containers[*].resources.requests.cpu,CPU_LIMIT:.spec.containers[*].resources.limits.cpu,MEMORY_REQUEST:.spec.containers[*].resources.requests.memory,MEMORY_LIMIT:.spec.containers[*].resources.limits.memory'
kubectl -n shoplite get pods -o custom-columns='POD:.metadata.name,RUN_AS_USER:.spec.securityContext.runAsUser,RUN_AS_NON_ROOT:.spec.securityContext.runAsNonRoot'
for pod in $(kubectl -n shoplite get pods -o name); do
  echo "$pod: $(kubectl -n shoplite exec "$pod" -- id)"
done
```

Every `id` shows a uid other than 0: 10001 (catalog-api, order-worker), 101 (web), 70
(postgres), 999 (redis).

Screenshots: `09-workloads.png`, `10-probes-pdb-hpa.png`, `11-postgres-seed.png`,
`12-resources-non-root.png`.

### 5b Secrets and configuration

The database credentials are in the Secret `shoplite-db`, made in the cluster by the bootstrap
(section 3); `describe` shows its keys, not their values. The settings are in the ConfigMap
`shoplite-config`. The pods read both by reference:

```bash
kubectl -n shoplite describe secret shoplite-db
kubectl -n shoplite get configmap shoplite-config -o go-template='{{range $key, $value := .data}}{{$key}}={{$value}}{{"\n"}}{{end}}'
kubectl -n shoplite set env deployment/catalog-api --list
```

No plain-text secret is in Git. The chart only names the Secret, and the password is made
randomly in the cluster:

```bash
grep -rn 'POSTGRES_PASSWORD' helm/ scripts/ ../shoplite-gitops/
```

Screenshots: `13-secret-configmap.png`, `14-no-secret-in-git.png`.

### 5c NetworkPolicy

Two policies, `postgres` and `redis`, select those pods. They admit only catalog-api and
order-worker of the same release, on the database's and the queue's own port. Tried from the
pods themselves:

```bash
kubectl -n shoplite get networkpolicies
kubectl -n shoplite describe networkpolicy postgres redis
check() { # check <deployment> <host> <port>: can the deployment's pod open the port?
  if kubectl -n shoplite exec "deploy/$1" -- nc -z -w 3 "$2" "$3" >/dev/null 2>&1
  then echo "$1 -> $2:$3 open"; else echo "$1 -> $2:$3 blocked"; fi
}
for from in catalog-api order-worker web; do check "$from" postgres 5432; check "$from" redis 6379; done
check web catalog-api 8000
kubectl -n shoplite-dev exec deploy/catalog-api -- nc -z -w 3 postgres.shoplite.svc.cluster.local 5432 >/dev/null 2>&1 &&
  echo "dev's catalog-api -> prod's postgres open" || echo "dev's catalog-api -> prod's postgres blocked"
```

What the checks show:
- catalog-api and order-worker reach both PostgreSQL and Redis.
- web is blocked from both. The same `nc` from web does reach catalog-api, so the block comes
  from the policy, not from the tool.
- Dev's catalog-api cannot reach prod's database.

Screenshot `15-networkpolicy.png`.

### 5d Ingress controller

Traefik (chart 42.2.0, Traefik v3.7.16) runs behind the ALB. ArgoCD installs it from
`shoplite-gitops/apps/traefik.yaml`:

- a NodePort Service;
- entrypoint `web` on NodePort 30080 (the ALB's port 80, prod);
- entrypoint `dev` on NodePort 30081 (the ALB's port 8080);
- `/ping` for the ALB's health check.

```bash
kubectl -n traefik get deployments,services
kubectl -n shoplite get ingresses
curl -s -o /dev/null -w '/ping through the ALB: %{http_code}\n' "$ALB/ping"
curl -s "$ALB/api/products/1"; echo
```

Screenshot `16-traefik.png`, together with question 4's `10-target-health.png` from section 3.

### 5e Helm chart

There is one chart, `helm/shoplite`, with a values file for each environment. ArgoCD renders
it once per environment, with three layers of values:

1. the chart's `values.yaml`;
2. that environment's values file in the chart;
3. the environment's values in shoplite-gitops: the image tag, and prod's fault-injection flags.

```bash
find helm/shoplite -type f | sort
helm lint helm/shoplite --strict -f helm/shoplite/values-dev.yaml
helm lint helm/shoplite --strict -f helm/shoplite/values-prod.yaml
kubectl -n argocd get applications shoplite-dev shoplite-prod -o custom-columns='APPLICATION:.metadata.name,CHART:.spec.sources[0].path,VALUE_FILES:.spec.sources[0].helm.valueFiles,NAMESPACE:.spec.destination.namespace'
```

Screenshot `17-helm-chart.png`.

## 6. Checkpoint: an order through the ALB

In the browser, open the prod URL (`echo "$ALB"`, the ALB's port 80). The page lists the
products. Click **Order** beside one. The order appears under "Your orders", and within a
few seconds its badge goes from `PENDING` through `PROCESSING` to `COMPLETED`. Record this
(video V2).

Then find the same order in prod's database:

```bash
kubectl -n shoplite exec postgres-0 -- sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT id, product_id, quantity, status, created_at, completed_at FROM orders ORDER BY id DESC LIMIT 3"'
```

Screenshots:
- `18-checkpoint-browser.png`: the page at the ALB's URL, the order `COMPLETED`.
- `19-checkpoint-database.png`: the order's row in prod's database.

## After the session

1. **shoplite-app** → Settings → Secrets and variables → Actions → Variables: set
   `LAB_ACTIVE` to `false`. Pushes between sessions then only build the images, and the run
   stays green.
2. Run question 4's [After grading](../q4/commands.md#after-grading), which ends with
   `terraform destroy`.

The cluster, ArgoCD and the ECR images go with the destroy; Git keeps everything else. The
next session starts again at section 1; the deploy key and the secret stay.
