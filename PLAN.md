# ShopLite Capstone: 110 মার্কের কাজের গাইড

## 0. শুরুতেই ছয়টা কথা

1. **প্রশ্নপত্র মিলিয়ে দেখা হয়েছে।** Poridhi-র page আর এই repo-র `project.md` শব্দ ধরে মেলানো হয়েছে। দুটো হুবহু এক, page-এর শেষে শুধু একটা footer লাইন বাড়তি। কোনো প্রশ্ন বা শর্ত বাদ পড়েনি। Page-এ architecture-এর কোনো ছবি নেই, শুধু লেখা তালিকা, তাই diagram নিজেকে আঁকতে হবে (section 2)।
2. **সব practice হবে Poridhi-র AWS lab-এ।** নিজের machine-এ বড়জোর Docker চলবে (Q1 আর Q2)। Lab-এর page-এ timer দেখায় 4 ঘণ্টা 59 মিনিট, তাই এক session সর্বোচ্চ ৫ ঘণ্টা ধরা হয়েছে। Session শেষে AWS resource থাকবে না, এটাও ধরে নেওয়া হয়েছে।
3. **তাই তিনটা নিয়ম।** (ক) যা Git-এ নেই তা session শেষে হারিয়ে যাবে, তাই শেষ হওয়ার আগে commit আর push। (খ) `make lab-up` এক command-এ প্রায় ৩০ মিনিটে পুরো environment আবার দাঁড় করাবে। (গ) যে session-এ কাজ, সেই session-এই তার screenshot আর ভিডিও।
4. **মোট সময় প্রায় ৪৮ ঘণ্টা, ১০টা lab session।** Core 100-এর জন্য প্রায় ৩৯ ঘণ্টা, bonus 10-এর জন্য প্রায় ৯। এর মধ্যে প্রায় ৫ ঘণ্টা যায় প্রতি session-এ environment দাঁড় করাতে। Deadline 17 Nov, তাই দিনে গড়ে ৭ ঘণ্টা।
5. **প্রশ্নে যা লেখা তা-ই মানা হবে।** যেখানে প্রশ্ন একাধিক পথ দিয়েছে, সেখানে একটা বেছে নেওয়া হয়েছে (section 1)। `README.md` বলছে gitops repo-তে "infrastructure" থাকবে, কিন্তু প্রশ্নপত্র বলছে Terraform, Helm আর monitoring থাকবে `shoplite-app`-এ। প্রশ্নপত্রটাই মানা হচ্ছে।
6. **Submission form নিজে দেখে নিতে হবে।** Form-এ ঠিক কী কী চায় (repo link, ভিডিও link, অন্য কিছু) তা শুরুতেই জেনে নাও।

## 1. যে সিদ্ধান্তগুলো নেওয়া হয়েছে

| বিষয় | সিদ্ধান্ত | কারণ |
|---|---|---|
| ভাষা | Python 3.12, API-তে FastAPI | নিজের পছন্দ |
| কোথায় কাজ | সব AWS lab-এ; নিজের machine-এ শুধু Docker | নিজের পছন্দ |
| Cluster (kubeadm বা k3s) | k3s | containerd, storage, metrics-server আর NetworkPolicy সাথেই আসে |
| Node-এর আকার | control-plane t3.medium, worker দুইটা t3.large | monitoring stack সহ সব কিছুর জায়গা হয়; lab-এ না পেলে t3.medium |
| Ingress (ingress-nginx বা Traefik) | Traefik | ingress-nginx প্রকল্পটা March 2026-এ retire করা হয়েছে |
| Log collector (Promtail বা Alloy) | Grafana Alloy | Promtail 2 March 2026 থেকে end-of-life |
| Admin access (bastion বা SSM) | SSM Session Manager | প্রশ্নেই লেখা "SSM preferred"; port 22 খুলতে হয় না |
| NAT (Gateway বা instance) | NAT Gateway | সবচেয়ে সোজা |
| State locking | S3 backend-এ `use_lockfile = true` | Terraform-এর নিজস্ব S3 lock; DynamoDB lock এখন deprecated |
| Alert কোথায় যাবে (Slack, email বা webhook) | Slack webhook | screenshot নেওয়া সহজ |
| Load test (k6, hey বা script) | k6 | latency বাড়লেও নির্দিষ্ট RPS ধরে রাখে |
| Q3-এর server (EC2 বা local VM) | Lab-এর একটা EC2 | সব কাজ lab-এ; এটাই Q2-এর "clean machine" হিসেবেও কাজ করবে |
| Secret | Cluster দাঁড় করানোর সময় বানানো Kubernetes Secret | Git-এ কিছু যায় না; cluster বারবার নতুন হয় বলে Sealed Secrets এখানে ঝামেলা |
| DB seed (Job বা script) | `init.sql` script, Postgres প্রথম চালুর সময় নিজেই চালায় | Compose আর Kubernetes-এ একই ফাইল; NetworkPolicy-তে বাড়তি ছাড় লাগে না |
| Environment | prod = namespace `shoplite`, dev = `shoplite-dev`, একই cluster | প্রশ্নে namespace `shoplite`; Q7-এ environment প্রতি আলাদা ArgoCD app |
| dev-এর URL | ALB-র port 8080 | domain ছাড়াই browser-এ dev দেখা যায় |
| Grafana আর ArgoCD দেখা | ALB-র `/grafana` আর `/argocd` path, password সহ | browser থেকে সরাসরি খোলে, lab-এ tunnel লাগে না |
| Bonus-এ AWS access (IRSA বা Pod Identity) | EKS Pod Identity | Terraform-এ কম অংশ লাগে |

## 2. Architecture diagram

```text
                          User (browser)
                                 |
                                 v
              +-------------------------------------+
              | ALB (public subnets, 2 AZ)          |
              | :80 -> prod          :8080 -> dev   |
              +------------------+------------------+
                                 |
+--------------------------------|------------------------------------------+
| VPC 10.0.0.0/16, 2 AZ          |               tag: project=shoplite      |
|                                |                                          |
|  +-------------------+   +-----v----------------------------------------+ |
|  | EC2 control-plane |   | EC2 worker-1 and worker-2 (k3s agents)       | |
|  | (k3s server)      |---|                                              | |
|  +-------------------+   | Traefik ingress (NodePort 30080 / 30081)     | |
|                          |    /     -> web          (Nginx, 2 pods)     | |
|                          |    /api  -> catalog-api  (2+ pods)           | |
|                          |                                              | |
|                          | catalog-api --INSERT--> PostgreSQL (PVC)     | |
|                          | catalog-api --LPUSH---> Redis orders:pending | |
|                          | order-worker <--BRPOP-- Redis                | |
|                          | order-worker --UPDATE-> PostgreSQL           | |
|                          |    (order-worker: HPA, 1 to 4 pods)          | |
|                          |                                              | |
|                          | ns monitoring: Prometheus, Loki, Tempo,      | |
|                          |                Grafana, Alertmanager, Alloy  | |
|                          | ns argocd:     ArgoCD                        | |
|                          +----------------------------------------------+ |
|                                                                           |
| PUBLIC  subnets a/b: Internet Gateway, NAT Gateway, ALB                   |
| PRIVATE subnets a/b: the 3 EC2 nodes, no public IP, admin access via SSM  |
+---------------------------------------------------------------------------+
 Outside the VPC: Amazon ECR (3 image repos), S3 (Terraform state + lock)

 Delivery : git push (shoplite-app) -> GitHub Actions: lint, test, build, Trivy
            -> push images to ECR (OIDC) -> commit image tag to shoplite-gitops
            -> ArgoCD pulls: dev = auto-sync + self-heal, prod = manual sync

 Signals  : /metrics -> Prometheus        JSON logs -> Alloy -> Loki
            OTLP traces -> Tempo          all linked in Grafana by trace_id
            alert rules -> Alertmanager -> Slack

 Tools    : http://<ALB>/grafana    http://<ALB>/argocd    (password protected)
```

এই repo-র `docs/architecture-diagram.md`-তে এটারই তিনটা ছবি আছে (infrastructure, delivery, observability), সাথে PNG। Live demo-তে "নিজের diagram" লাগবে, তাই ছবিগুলো একবার নিজে হাতে ঘুরিয়ে-ফিরিয়ে বুঝে নিও।

## 3. Project structure

প্রশ্নপত্রের tree হুবহু রাখা হয়েছে। `+` চিহ্ন মানে প্রশ্নে নেই কিন্তু কাজ চালাতে লাগবে (প্রশ্নে বাড়তি ফাইল রাখার অনুমতি আছে)।

```text
shoplite-app/
├── README.md                  + কীভাবে চালাবে, evidence index, deviation log
├── Makefile                   build up down test smoke  (+ lint, lab-up, lab-down, tunnel, loadtest)
├── docker-compose.yml
├── .env.example  .gitignore   +
├── services/
│   ├── web/                   Dockerfile, .dockerignore, nginx template, public/
│   ├── catalog-api/           Dockerfile, .dockerignore, app/, tests/
│   └── order-worker/          Dockerfile, .dockerignore, worker/, tests/
├── scripts/
│   ├── smoke-test.sh
│   ├── install-tools.sh       + নতুন lab machine-এ সব tool বসায়
│   ├── lab-preflight.sh       + lab-এ কী কী অনুমতি আছে তা যাচাই
│   ├── bootstrap-cluster.sh   + namespace, secret, ArgoCD, root app
│   └── loadtest.js            + k6
├── linux/
│   ├── sshd_config
│   ├── systemd/               shoplite-backup.service, .timer, backup script
│   ├── firewall/              UFW rule script, status output
│   └── evidence/              screenshot, commands.md
├── terraform/
│   ├── bootstrap/             + state bucket
│   ├── q3-server/             + Q3-এর EC2
│   ├── main.tf  backend.tf  variables.tf  outputs.tf
│   └── modules/
│       ├── network/  compute/  alb/  ecr/
│       ├── github-oidc/       + CI-এর IAM role
│       ├── eks/               + Bonus 1
│       └── messaging/         + Bonus 2 (SQS, Lambda)
├── ansible/                   site.yml, roles/{hardening,container_runtime,k3s_server,k3s_agent,kubeconfig}
├── helm/shoplite/             Chart.yaml, values.yaml, values-dev.yaml, values-prod.yaml, files/init.sql, templates/
├── monitoring/
│   ├── dashboards/            golden-signals.json
│   ├── alert-rules/           shoplite-alerts.yaml  (+ slo-burn-rate.yaml)
│   ├── runbooks/              HighErrorRate.md ... (৫টা)
│   ├── stack/                 + kube-prometheus-stack, loki, tempo, alloy-এর values
│   └── kustomization.yaml     + dashboard -> ConfigMap, rules -> PrometheusRule
├── .github/workflows/         pr.yml, main.yml, terraform-plan.yml, promote.yml
└── docs/
    ├── architecture-diagram.png  (+ source)
    ├── RCA.md
    ├── evidence/              + q1 ... q8, bonus
    ├── chaos-menu.md          + Q8-এ peer-এর জন্য নির্দেশ
    ├── lab-notes.md           + lab-এর সীমাবদ্ধতা
    └── demo-script.md         +

shoplite-gitops/
├── README.md                  +
├── bootstrap/root-app.yaml    + সব app-কে ধরে রাখা "app of apps"
├── apps/                      ArgoCD Application
│   ├── shoplite-dev.yaml      auto-sync + prune + self-heal
│   ├── shoplite-prod.yaml     manual sync
│   ├── traefik.yaml  kube-prometheus-stack.yaml  loki.yaml  tempo.yaml  alloy.yaml
│   ├── monitoring-config.yaml dashboard আর alert rule
│   └── argo-rollouts.yaml     + Bonus 3
└── envs/
    ├── dev/values.yaml        image registry আর tag (CI লেখে)
    └── prod/values.yaml       image tag, আর chaos flag-এর জায়গা (Q8)
```

## 4. সময়, মার্ক আর lab session

নিচে S1 থেকে S10 মানে lab session ১ থেকে ১০। B1 থেকে B4 মানে প্রশ্নের Bonus 1 থেকে Bonus 4।

| # | Phase | কোথায় | ঘণ্টা | মার্ক | জমা মার্ক |
|---|---|---|---|---|---|
| 0 | প্রস্তুতি | lab লাগে না | 1.0 | – | 0 |
| 1 | Q1: application | Docker | 2.5 | 8 | 8 |
| 2 | Q2: Docker | Docker | 1.5 | 10 | 18 |
| 3 | Lab যাচাই (preflight) | S1 | 0.75 | – | 18 |
| 4 | Q3: Linux server | S1 | 1.5 | 5 | 23 |
| 5 | Q4: Terraform, Ansible | S1, S2 | 7.0 | 17 | 40 |
| 6 | GitOps-এর ভিত, Q5: Helm chart | S3 | 4.25 | 15 | 55 |
| 7 | Q6: observability | S4, S5 | 8.0 | 25 | 80 |
| 8 | Q7: CI/CD, GitOps | S6 | 4.0 | 10 | 90 |
| 9 | Q8: Chaos Day, RCA | S7 | 4.5 | 10 | 100 |
| 10 | Docs, শেষ প্রমাণ, demo-র মহড়া | S10 | 4.0 | রক্ষা | 100 |
| | **Core মোট** | | **39.0** | **100** | |
| B4 | Bonus 4: SLO, burn-rate alert | S7 | 0.75 | +2 | 102 |
| B3 | Bonus 3: canary | S8 | 1.5 | +2 | 104 |
| B2 | Bonus 2: SQS, Lambda | S8 | 3.0 | +3 | 107 |
| B1 | Bonus 1: EKS | S9 | 4.0 | +3 | 110 |
| | **মোট** | | **48.25** | **110** | |

প্রতিটা session-এর ঘণ্টার মধ্যে environment দাঁড় করানোর ৩০ মিনিট ধরা আছে।

**Lab session অনুযায়ী**

| Session | ঘণ্টা | কাজ |
|---|---|---|
| S1 | 4.75 | Lab যাচাই, Q3, Q4-এর Terraform |
| S2 | 4.5 | Q4-এর Ansible, `make lab-up`, Q4-এর প্রমাণ |
| S3 | 4.25 | ArgoCD, Traefik, pipeline-এর প্রথম সংস্করণ, Q5 |
| S4 | 4.0 | Q6: stack বসানো |
| S5 | 4.0 | Q6: dashboard, correlation, alert |
| S6 | 4.0 | Q7 |
| S7 | 4.25 | Q8-এর মহড়া, Chaos Day, তারপর B4 |
| S8 | 4.5 | B3, B2 |
| S9 | 4.0 | B1 (EKS) |
| S10 | 2.0 | শেষ প্রমাণ, demo-র মহড়া, destroy |
| Demo | 1.5 | Live demo (৪৫ মিনিট আগে `make lab-up`) |

**কোন লক্ষ্যে কত সময়**

| লক্ষ্য | যা বাদ যায় | ঘণ্টা | Lab session |
|---|---|---|---|
| 110 | কিছু না | প্রায় 48 | 10 |
| 107 | Bonus 1 (EKS) | প্রায় 44 | 9 |
| 104 | Bonus 1 আর 2 | প্রায় 42 | 9 |
| 100 | সব bonus | প্রায় 39 | 8 |

**অগ্রাধিকার**

- Q1 থেকে Q8 ক্রম ধরে করো; প্রতিটা আগেরটার উপর দাঁড়ায়।
- Core-এর কোনো প্রমাণ বাকি রেখে bonus ধরবে না। প্রশ্নেও লেখা আছে, bonus শুধু Q1–Q8 শেষ হলে।
- Bonus-এর ক্রম: B4, B3, B2, B1। প্রতি ঘণ্টায় সবচেয়ে বেশি মার্ক আগে।
- কোনো এক সমস্যায় ৪৫ মিনিটের বেশি আটকে থাকলে থামো, বিকল্প পথ নাও, পরে ফিরে এসো।
- Lab-এর resource যদি session-এর পরেও থেকে যায়, প্রায় ৪ ঘণ্টা বাঁচবে। S1-এর যাচাইয়ে এটা জানা যাবে।

## 5. প্রতিটা lab session-এর শুরু আর শেষ

**শুরুতে (প্রায় ৩০ মিনিট, বেশিরভাগটা নিজে নিজে চলে)**

1. Lab চালু করে AWS credential নাও।
2. `shoplite-app` আর `shoplite-gitops` clone করো।
3. `scripts/install-tools.sh` চালাও: Terraform, Ansible, kubectl, helm, AWS CLI, Session Manager plugin, k6, gh। Lab-এর machine প্রতিবার নতুন হলে এটা প্রতিবারই লাগবে।
4. নিজের secret-গুলো (Slack webhook URL, GitHub token) environment-এ বসাও।
5. `make lab-up`।
6. ALB-র URL খুলে দেখো, তারপর ৫ মিনিট হালকা load চালাও যাতে dashboard-এ data আসে।

**শেষ হওয়ার ২০ মিনিট আগে**

1. ওই session-এর প্রমাণের তালিকা মিলিয়ে নাও।
2. সব commit আর push।
3. `make lab-down`।

## 6. ধাপে ধাপে কাজ

**কাজের নিয়ম**

- প্রতিটা phase-এর শুরুতে এই ফাইলের ওই অংশটা আবার পড়ো।
- কোড lab session-এর আগেই তৈরি থাকবে। Lab-এর সময় যাবে শুধু চালানো, ঠিক করা আর প্রমাণ নেওয়ায়।
- সব commit সরাসরি `main`-এ, নিজের নামে। Q7 (b)-এর প্রমাণের জন্য শুধু এক-দুইটা pull request খোলা হবে।
- প্রতিটা phase শেষে ১০ মিনিট নিয়ে কোডটা বুঝে নাও। Live demo-তে ব্যাখ্যা তোমাকেই করতে হবে।

### Phase 0: প্রস্তুতি (1 ঘণ্টা, lab লাগে না)

1. GitHub-এ দুইটা repo বানাও: `shoplite-app`, `shoplite-gitops`। Public রাখলে grader আর ArgoCD দুজনেই বাড়তি credential ছাড়া পড়তে পারে।
2. একটা fine-grained GitHub token বানাও, শুধু এই দুই repo-র জন্য (Contents, Actions, Variables)। Lab-এর machine থেকে push করতে আর pipeline চালাতে লাগবে।
3. Slack-এ একটা incoming webhook বানাও।
4. Slack URL, GitHub token আর পরে বানানো password-গুলো password manager-এ রাখো। এগুলো Git-এ যাবে না।
5. নিজের machine-এ Docker ঠিকমতো চলছে কিনা দেখো।
6. Q8-এর জন্য একজন peer আজই ঠিক করো।
7. Submission form আর live demo-র তারিখ জেনে নাও।

### Phase 1: Q1, application (8 মার্ক, 2.5 ঘণ্টা, Docker)

| অংশ | মার্ক | "হয়ে গেছে" মানে |
|---|---|---|
| (a) API | 3 | ৭টা endpoint, সঠিক status code (200, 201, 404, 422, 503) |
| (b) Database | 1 | `products` ও `orders` table, নিজে থেকে ১০টার বেশি product seed |
| (c) Config, logging | 2 | সব config env থেকে; JSON log-এ `timestamp, level, service, message, trace_id`; worker `SIGTERM` পেলে চলমান order শেষ করে বন্ধ হয় |
| (d) Unit test | 1 | কমপক্ষে ৫টা API test (১০টা রাখা হবে), DB বা Redis ছাড়াই চলে |
| (e) Chaos flag | 1 | ৪টা flag, default বন্ধ |

`web`-এ তিনটা কাজ থাকবে: product-এর তালিকা, order দেওয়া, order-এর status দেখা।

**এখনই ঠিকভাবে না বানালে পরে মার্ক হারাবে**

- ৬টা metric ঠিক প্রশ্নের নামে আর label-এ। `route` label-এ থাকবে template (`/products/{id}`), আসল path নয়।
- Latency histogram-এ exemplar হিসেবে `trace_id` যাবে, আর `/metrics` OpenMetrics format-এ দিতে হবে (Q6-এর exemplar)।
- Queue-র message-এ `traceparent` থাকবে; worker সেখান থেকে একই trace চালিয়ে যাবে (Q6-এর ৬ মার্ক)।
- Histogram-এর bucket-এ 0.5 আর 1.0 সেকেন্ড থাকতে হবে (alert আর SLO এই সীমা ব্যবহার করে)।
- Queue-র জন্য ছোট একটা interface, `QUEUE_BACKEND=redis|sqs`। এতে Bonus 2 সহজ হয়।
- Worker-এ `WORKER_CONCURRENCY` (default 4), যাতে স্বাভাবিক load-এ queue না জমে।
- "Processing"-এর ১–২ সেকেন্ডের মধ্যে সামান্য CPU-র কাজ, যাতে CPU-ভিত্তিক HPA সত্যিই scale করে।
- `CHAOS_MEMORY_LEAK` চালু হলে প্রতি order-এ প্রায় 1 MB ধরে রাখো, যাতে ১৫ মিনিটের মধ্যে ধরা পড়ে।
- Chaos flag-এর মান log-এ ছাপাবে না। Q8-এ সেটা env দেখার সমান হয়ে যায়।
- web-এর `index.html`-এ `Cache-Control: no-cache`, যাতে Q7-এর title বদল সাথে সাথে দেখা যায়।

**প্রমাণ (`docs/evidence/q1/`):** test pass-এর output; প্রতিটা endpoint-এর response ও status code; এক লাইন JSON log; `docker stop` দিলে worker-এর সুন্দরভাবে বন্ধ হওয়া; চারটা chaos flag-এর প্রভাব।

### Phase 2: Q2, Docker (10 মার্ক, 1.5 ঘণ্টা, Docker)

| অংশ | মার্ক | "হয়ে গেছে" মানে |
|---|---|---|
| (a) Dockerfile | 4 | তিনটা Dockerfile: multi-stage, non-root, `HEALTHCHECK`, `.dockerignore`, প্রতিটা image 150 MB-এর কম |
| (b) Compose | 3 | পাঁচটা component, `pgdata` named volume, healthcheck-ভিত্তিক `depends_on` |
| (c) Smoke test | 2 | stack চালু, `/readyz`, order, `COMPLETED`; কোনো ধাপ ব্যর্থ হলে non-zero exit |
| (d) Makefile | 1 | `build up down test smoke` |

**মূল বিষয়**

- API আর worker: `python:3.12-alpine`, builder stage-এ dependency, final stage-এ শুধু দরকারি ফাইল, user id 10001। `python:slim` নিলে 150 MB পেরিয়ে যাওয়ার ঝুঁকি থাকে।
- Trace পাঠানো হবে OTLP/HTTP দিয়ে; gRPC package ভারী।
- web: `nginxinc/nginx-unprivileged` (port 8080, non-root)।
- Compose-এ API-র port `127.0.0.1`-এ বাঁধা থাকবে, বাইরে খোলা থাকবে শুধু web। Q3-এর firewall পরীক্ষায় এটা কাজে লাগে।
- `make test` Docker-এর ভেতরে চলবে, যাতে clean machine-এ Python না থাকলেও চলে।
- `.env` না থাকলে Makefile `.env.example` থেকে বানিয়ে নেবে। Smoke test-এ `jq` লাগবে না।

**Checkpoint:** `make up && make smoke`, clean machine-এ। এটার চূড়ান্ত প্রমাণ নেওয়া হবে S1-এ, Q3-এর নতুন EC2-তে (ভিডিও V1)।

**প্রমাণ (`docs/evidence/q2/`):** `docker images` (size), `docker ps` (healthy), container-এর user root নয়, আর V1।

### Phase 3: Lab যাচাই (45 মিনিট, S1)

Tool বসিয়ে `scripts/lab-preflight.sh` চালাও। Script ছোট পরীক্ষামূলক resource বানিয়ে আবার মুছে দেখবে কোনটা করা যায়:

- `aws sts get-caller-identity`: account ID কি প্রতি session-এ বদলায়?
- কোন region, আর t3.medium বা t3.large চালু করা যায় কিনা।
- IAM role, instance profile আর OIDC provider বানানো যায় কিনা। SSM, ECR থেকে image টানা আর GitHub OIDC তিনটাই এর উপর নির্ভর করে।
- NAT Gateway, ALB, ECR, S3 bucket বানানো যায় কিনা।
- Budgets, Route 53, EKS, SQS, Lambda-তে অনুমতি আছে কিনা।
- Session কত ঘণ্টার, দিনে কয়টা নেওয়া যায়, আর শেষ হলে resource মুছে যায় কিনা।

ফলাফল `docs/lab-notes.md`-তে লিখে রাখো।

**Lab-এ কিছু নিষেধ থাকলে**

| যা করা যায় না | বিকল্প |
|---|---|
| IAM role বা instance profile | SSM-এর বদলে bastion host (প্রশ্নে অনুমোদিত); ECR-এর জন্য session-এর শুরুতে বানানো pull secret |
| OIDC provider | Instructor-কে জানাও; এটা ছাড়া Q7 (a)-র OIDC অংশ দেখানো যায় না |
| Budgets | Terraform code রেখে দাও, AccessDenied-এর screenshot নাও, README-তে লেখো |
| NAT Gateway | NAT instance (প্রশ্নে অনুমোদিত) |
| t3.large | t3.medium, সাথে monitoring-এর resource request কমানো |
| EKS, SQS বা Lambda | ওই bonus lab-এ সম্ভব নয়; instructor-কে জিজ্ঞেস করো, নয়তো বাদ |

### Phase 4: Q3, Linux server (5 মার্ক, 1.5 ঘণ্টা, S1)

1. `terraform/q3-server` দিয়ে একটা Ubuntu 24.04 EC2 বানাও, public IP সহ। Security group-এ নিজের IP থেকে 22, 80, 443, আর পরীক্ষার জন্য 8000। 8000 ইচ্ছা করে খোলা রাখা, যাতে প্রমাণ হয় port-টা আটকাচ্ছে UFW, security group নয়।
2. Server-এ repo clone করে `make up && make smoke` চালাও। এটাই Q2-এর clean machine checkpoint (V1)।
3. তারপর নিচের চারটা কাজ। প্রতিটার command `linux/evidence/commands.md`-তে, সাথে screenshot।

| অংশ | মার্ক | কী করতে হবে | প্রমাণ |
|---|---|---|---|
| 3.1 Users, SSH | 1.5 | `deploy` user, `ops` group; `PermitRootLogin no`, `PasswordAuthentication no` | root দিয়ে login প্রত্যাখ্যাত; password দিয়ে login প্রত্যাখ্যাত; `sshd -T`-র কার্যকর মান |
| 3.2 Permission | 1 | `chown root:ops`, `chmod 2750`, আর একটাই `setfacl` (নতুন ফাইলেও ops পড়তে পারবে) | `ls -l`, `getfacl`; `deploy` পড়তে পারে, অন্য user পারে না; 777 কেন ভুল, এক লাইনে |
| 3.3 Backup | 1.5 | `shoplite-backup.service` (`Restart=on-failure`), `.timer` (প্রতি রাতে), `pg_dump` যায় `/var/backups/shoplite/`-এ | `systemctl status`, `systemctl list-timers`, backup ফাইলের তালিকা |
| 3.4 Firewall | 1 | UFW: default deny, শুধু 22, 80, 443 | `ufw status verbose`, `ss -tulpn`; lab-এর terminal থেকে port 80 খোলা আর port 8000 বন্ধ |

**ফাঁদ**

- `sshd_config.d`-র ফাইল আগে পড়া হয় আর প্রথম মানটাই টেকে। তাই `sshd -T` দিয়ে কার্যকর মান দেখো। Ubuntu 24.04-এ service-এর নাম `ssh`।
- Docker নিজে iptables rule বসায়, UFW মানে না। তাই Compose থেকে শুধু port 80 বাইরে খোলা থাকবে। নইলে "বন্ধ" port বাইরে থেকে খোলা দেখাবে।
- SSH বা firewall বদলানোর সময় দ্বিতীয় একটা SSH session খোলা রাখো।

### Phase 5: Q4, Terraform আর Ansible (17 মার্ক, 7 ঘণ্টা, S1 আর S2)

S1-এ Terraform, S2-তে Ansible আর `make lab-up`।

| অংশ | মার্ক | "হয়ে গেছে" মানে | প্রমাণ |
|---|---|---|---|
| (a) VPC | 4 | ২ AZ, ২ public ও ২ private subnet, IGW, NAT Gateway | `terraform state list`, subnet আর route table-এর CLI output |
| (b) Security group | 3 | Internet থেকে node-এ কিছুই ঢোকে না, port 22-ও না; ALB থেকে শুধু ingress-এর port | SG rule-এর তালিকা; node-এ public IP নেই |
| (c) Compute | 1 | ১ control-plane ও ২ worker, private subnet-এ; ঢোকার পথ SSM | `aws ssm start-session` কাজ করছে |
| (d) ALB | 2 | Public subnet-এ, traffic যায় Traefik-এ | target health "healthy"; ALB URL-এ page খোলে |
| (e) ECR, state | 2 | ৩টা ECR repo; state S3-এ, lock সহ | repo-র তালিকা; bucket-এ state আর lock ফাইল |
| (f) Module | 1 | `network`, `compute`, `alb`, `ecr` | module-এর tree |
| (g) Ansible | 4 | Q3-এর hardening প্রতিটা node-এ; container runtime; k3s; worker join; kubeconfig | playbook-এর প্রথম run; দ্বিতীয় run-এ `changed=0`; `kubectl get nodes`-এ ৩টা Ready |
| Cost guard | – | প্রতিটা resource-এ `project=shoplite`; USD 20-র Budget; শেষে destroy | tag দিয়ে resource খোঁজার output; budget; `terraform destroy`-এর output |

**মূল বিষয়**

- Provider-এর `default_tags` দিয়ে সব resource-এ `project=shoplite` একবারেই বসে।
- Console শুধু billing দেখার জন্য। State bucket-ও Terraform দিয়ে (`terraform/bootstrap`)।
- Ansible private node-এ পৌঁছাবে SSM-এর ভেতর দিয়ে চলা SSH-এ। `kubectl`-এর জন্য SSM port-forward (`make tunnel`)।
- k3s-এর সাথে আসা Traefik বন্ধ রেখে Traefik আলাদা chart দিয়ে বসবে, যাতে k3s আর EKS দুই জায়গায় একই config চলে।
- k3s-এ containerd ভেতরেই থাকে। `container_runtime` role দরকারি kernel setting বসাবে আর containerd চালু আছে কিনা যাচাই করে version ছাপাবে।
- ECR থেকে image টানতে node-এর IAM role আর kubelet-এর ECR credential provider লাগবে।
- `hardening` role বসাবে 3.1, 3.2 আর 3.4। 3.3 (backup) hardening নয়, আর node-এ Compose-এর Postgres নেই।

**সবচেয়ে বড় ফাঁদ: Kubernetes node-এ UFW।** Q3-এর নিয়ম (default deny; 22, 80, 443) হুবহু বসালে cluster ভেঙে যায়। তাই node-এ ওই তিনটার সাথে cluster-এর ভেতরের port (6443, 10250, 8472/udp) শুধু VPC-র ভেতর থেকে খোলা থাকবে, আর forward policy হবে ACCEPT। বাইরে থেকে ঢোকা আটকায় security group। এটা README-র deviation log-এ লিখে দিও।

**`make lab-up` যা করে**

1. State bucket বানায়।
2. `terraform apply`।
3. SSM-এ তিনটা node আসা পর্যন্ত অপেক্ষা করে।
4. Ansible চালায়, kubeconfig আনে।
5. Namespace, secret, ArgoCD আর root app বসায়।
6. GitHub-এ role ARN আর registry-র মান বসায়, pipeline চালিয়ে image push করায়, prod-এ tag তোলে আর প্রথম sync করে।
7. শেষে ALB, Grafana আর ArgoCD-র ঠিকানা ছাপায়।

Phase 5-এ প্রথম চারটা ধাপ তৈরি হবে; ৫ আর ৬ যোগ হবে Phase 6-এ। `make lab-down` মানে `terraform destroy`।

### Phase 6: GitOps-এর ভিত আর Q5, Helm chart (15 মার্ক, 4.25 ঘণ্টা, S3)

Cluster প্রতি session-এ নতুন হয়, তাই cluster-এ যা বসবে সব প্রথম দিন থেকেই Git থেকে ArgoCD দিয়ে বসবে। হাতে কিছু install করা হবে না।

**আগে ভিত (প্রায় ১.৫ ঘণ্টা)**

1. `shoplite-gitops`-এর কাঠামো: root app, dev আর prod-এর app, Traefik-এর app।
2. `scripts/bootstrap-cluster.sh`: namespace, DB password-এর Secret, ArgoCD, root app।
3. Pipeline-এর প্রথম সংস্করণ: build → ECR push (OIDC) → gitops-এ registry আর tag commit। Cluster-এ image পৌঁছানোর এটাই পথ, আর ECR প্রতি session-এ নতুন বলে `make lab-up` এই pipeline চালায়।
4. ArgoCD দেখা যাবে `http://<ALB>/argocd`-এ। Reconciliation 60 সেকেন্ডে নামানো থাকবে।

**তারপর Q5**

| অংশ | মার্ক | "হয়ে গেছে" মানে |
|---|---|---|
| (a) Workload, security | 7 | নিচের ৫টা workload; প্রতিটা pod-এ requests ও limits; কোনো container root নয় |
| (b) Secret, ConfigMap | 2 | DB credential Secret-এ, app setting ConfigMap-এ, Git-এ কোনো plain-text secret নেই |
| (c) NetworkPolicy | 2 | শুধু `catalog-api` আর `order-worker` Postgres ও Redis-এ ঢুকতে পারে |
| (d) Ingress controller | 1 | ALB-র পেছনে Traefik |
| (e) Helm chart | 3 | সব কিছু এক chart-এ; dev আর prod-এর আলাদা values ফাইল |

**Chart-এ যা থাকবে**

- `web`: Deployment (2 replica), Service, Ingress `/`।
- `catalog-api`: Deployment (2+), probe `/healthz` ও `/readyz`, PDB `minAvailable: 1`, Ingress `/api`, ServiceMonitor।
- `order-worker`: Deployment, CPU-ভিত্তিক HPA (1–4), `terminationGracePeriodSeconds: 30`, ServiceMonitor।
- `postgres`: StatefulSet, PVC, `init.sql` ConfigMap থেকে।
- `redis`: Deployment, শুধু ClusterIP Service।
- ConfigMap (app setting আর chaos flag), Secret-এর reference, দুইটা NetworkPolicy।

**Chart ঠিক করার চক্র:** `helm lint` আর `helm template` দিয়ে আগে দেখো → push → ArgoCD এক মিনিটে dev-এ বসায় → দেখো।

**ফাঁদ**

- `/api` থেকে prefix কেটে API-তে পাঠাতে Traefik-এর `StripPrefix` middleware লাগে, তাই web আর API-র Ingress আলাদা হবে।
- Postgres-এর image `postgres:16-alpine`-এ pin করো (18 থেকে data folder-এর গঠন বদলেছে)। Non-root চালাতে `runAsUser`, `fsGroup` আর `PGDATA`-র জন্য subfolder লাগবে।
- Bitnami chart ব্যবহার কোরো না; ওদের বিনামূল্যের image আর নিয়মিত পাওয়া যায় না, আর প্রশ্নও নিজের chart চায়।
- HPA থাকলে Deployment-এ `replicas` লিখবে না, নইলে ArgoCD আর HPA টানাটানি করবে।
- Pod template-এ ConfigMap-এর checksum annotation দাও। না দিলে values বদলালেও pod নতুন হবে না, আর Q8-এ chaos flag কাজই করবে না।

**Checkpoint:** ALB-র URL-এ browser থেকে order দাও, `COMPLETED` হওয়া পর্যন্ত দেখো (V2)।

**প্রমাণ (`docs/evidence/q5/`):** `shoplite` namespace-এর সব resource; `kubectl get hpa`-তে CPU-র শতাংশ; PDB; `web` pod থেকে Postgres-এ সংযোগ আটকে যাচ্ছে কিন্তু `catalog-api` থেকে হচ্ছে; প্রতিটা pod-এ `id` চালালে uid 0 নয়; Secret আর ConfigMap; `helm lint`; V2।

### Phase 7: Q6, observability (25 মার্ক, 8 ঘণ্টা, S4 আর S5)

সবচেয়ে বেশি মার্ক এখানে। লক্ষ্য: একটা alert থেকে শুরু করে শুধু Grafana দিয়ে ২ মিনিটের মধ্যে ঠিক যে request-টা ব্যর্থ হয়েছে সেখানে পৌঁছানো।

| অংশ | মার্ক | "হয়ে গেছে" মানে |
|---|---|---|
| (a) Stack | 5 | `monitoring` namespace-এ Prometheus, Loki, Alloy, Tempo, Grafana, Alertmanager চালু; Slack-এ notification আসে |
| (b) App metrics | 5 | ৬টা metric `/metrics`-এ, ServiceMonitor দিয়ে scrape হচ্ছে |
| (c) Dashboard | 5 | "ShopLite — Golden Signals" (নাম হুবহু), ৭টা panel, JSON Git-এ |
| (d) Correlation | 6 | নিচের ৪টা জিনিস |
| (e) Alert, runbook | 4 | ৫টা alert, প্রতিটায় `severity` আর `runbook_url`; ৫টা runbook |

**S4: stack বসানো**

| কাজ | Tool | মূল setting |
|---|---|---|
| Metrics, alert, dashboard | `kube-prometheus-stack` | k3s-এ etcd, scheduler, controller-manager, proxy-র scrape বন্ধ; সব ServiceMonitor ধরার selector; `exemplar-storage` চালু |
| Logs | Loki (single binary) | filesystem storage, replication 1, cache বন্ধ |
| Log collector | Alloy (DaemonSet) | সব pod-এর log, JSON parse; label শুধু `level` আর `service`, `trace_id` label নয় |
| Traces | Tempo (single binary) | OTLP receiver চালু |

Loki আর Tempo-র chart এখন `grafana-community/helm-charts`-এ। বসানোর দিন সর্বশেষ stable version দেখে pin করো। S4-এর শেষে ৬টা metric Prometheus-এ, log Loki-তে, trace Tempo-তে আর একটা পরীক্ষামূলক alert Slack-এ পৌঁছানো চাই।

**S5: dashboard, correlation, alert**

Dashboard-এর panel (প্রশ্নের ৭টা): route অনুযায়ী p50, p95, p99 latency; requests per second; 5xx error rate; pod অনুযায়ী CPU ও memory; queue depth; worker replica সংখ্যা; orders created বনাম processed।

বাড়তি ৩টা panel, Q8-এর জন্য জরুরি: pod restart ও শেষবার বন্ধ হওয়ার কারণ (OOMKilled); deploy-এর সময়ের চিহ্ন; সাম্প্রতিক error log। Q8-এ `kubectl` ব্যবহার করা যাবে না, তাই এগুলো Grafana-তেই থাকতে হবে।

Correlation-এর ৪টা জিনিস (৬ মার্ক):

1. Trace context queue-র ভেতর দিয়ে যায়।
2. এক order-এর পুরো পথ এক trace-এ: API → queue → worker → database।
3. Loki-র log-এর `trace_id` থেকে Tempo-র trace-এ link, আর trace থেকে তার log-এ ফেরার link।
4. Latency panel-এ exemplar বিন্দু, যেখানে click করলে trace খোলে।

Alert (প্রতিটা route আলাদা করে মাপা হবে, নইলে এক route-এর সমস্যা গড়ে ঢাকা পড়ে):

```text
HighErrorRate   critical  for 5m   route-wise 5xx ratio > 5%
HighLatency     warning   for 5m   route-wise p95 > 1s
QueueBacklog    warning   for 10m  max(order_queue_depth) > 50
PodCrashLooping critical           increase(kube_pod_container_status_restarts_total[10m]) > 0
NodeDiskFilling warning   for 5m   root filesystem usage > 85%
```

প্রতিটা runbook-এ থাকবে: লক্ষণ, প্রভাব, প্রথম ৫ মিনিটে কোন panel আর কোন query দেখবে, সমাধান।

**ফাঁদ**

- ServiceMonitor বানানোর পরও target না এলে selector-এর setting দেখো (`serviceMonitorSelectorNilUsesHelmValues: false`)।
- kube-prometheus-stack-এর CRD বড়, তাই ওই ArgoCD app-এ `ServerSideApply=true` লাগবে।
- Dashboard-এর JSON-এ `{{ }}` থাকে, Helm template-এ দিলে ভাঙে। তাই Kustomize দিয়ে ConfigMap বানানো হবে।
- Datasource-এর UID নির্দিষ্ট রাখো (`prometheus`, `loki`, `tempo`), নইলে cluster নতুন হলে link ভেঙে যায়।
- Slack webhook URL যাবে Secret-এ, values ফাইলে নয়।

**প্রমাণ (`docs/evidence/q6/`):** Grafana-তে `up` query দিয়ে সব target; ৬টা metric; load চলা অবস্থায় পুরো dashboard; এক order-এর trace; log থেকে trace আর trace থেকে log; exemplar; ৫টা alert rule; Slack-এ আসা alert; আর "alert থেকে failing request, ২ মিনিটে" ভিডিও (V3)।

### Phase 8: Q7, CI/CD আর GitOps (10 মার্ক, 4 ঘণ্টা, S6)

| অংশ | মার্ক | "হয়ে গেছে" মানে | প্রমাণ |
|---|---|---|---|
| (a) main pipeline | 5 | lint (Hadolint, `helm lint`), test, build (tag = short SHA), Trivy (CRITICAL হলে fail), OIDC দিয়ে ECR push, gitops-এ tag commit | সবুজ pipeline run; ECR-এ SHA tag; gitops-এ CI-র commit; ইচ্ছা করে পুরনো base image দিয়ে Trivy-র লাল run |
| (b) PR pipeline | 1 | PR-এ lint, test, build, scan; `terraform/` বদলালে plan comment হিসেবে | PR-এর check; plan সহ comment |
| (c) ArgoCD | 3 | environment প্রতি একটা Application; dev auto-sync, prod manual; self-heal চালু | দুই app-এর screenshot ও YAML |
| (d) Self-heal | 1 | `kubectl` দিয়ে বদলালে ArgoCD ফিরিয়ে আনে | ভিডিও V5 |
| Checkpoint | – | title বদলে push, কোনো deploy command ছাড়া browser-এ | ভিডিও V4 |

Phase 6-এ build, push আর tag commit হয়ে গেছে। এখানে যোগ হবে lint, test, Trivy-র gate, PR pipeline, Terraform plan-এর comment আর prod-এ তোলার `promote` workflow।

**মূল বিষয়**

- Pipeline-এ `kubectl` নেই, cluster-এর কোনো credential-ও নেই।
- Third-party action commit SHA দিয়ে pin করো। March 2026-এ `trivy-action`-এর tag hijack হয়েছিল।
- অন্য repo-তে push করতে `GITHUB_TOKEN` চলে না। gitops repo-র জন্য আলাদা deploy key লাগবে।
- CI tag লেখে dev-এর values-এ। prod-এ তোলার জন্য আলাদা `promote` workflow, তারপর হাতে sync।
- ArgoCD-তে self-heal হলো automated sync-এর অংশ। prod manual, তাই self-heal দেখানো হবে dev-এ। README-তে এটা লিখে দিও।
- Lab বন্ধ থাকলে AWS-এর role থাকে না। তখন pipeline-এর push ধাপ নিজে থেকে বাদ যাবে (`LAB_ACTIVE` variable), যাতে run লাল না হয়।
- Q7 (b)-এর প্রমাণের জন্য দুইটা PR খোলো: একটা সাধারণ, একটা `terraform/` বদলে।

### Phase 9: Q8, Chaos Day আর RCA (10 মার্ক, 4.5 ঘণ্টা, S7)

| অংশ | মার্ক | "হয়ে গেছে" মানে |
|---|---|---|
| (a) Exercise | 3 | প্রশ্নের ৬টা ধাপ হুবহু; সময়সহ screenshot |
| (b) RCA | 5 | ১–২ পৃষ্ঠা: timeline, detection, investigation, root cause, recovery time, একটা preventive measure |
| (c) Recovery | 2 | Git revert দিয়ে ঠিক করা; dashboard-এ স্বাভাবিক হওয়া দেখানো |

**কোন flag-এ কী দেখা যাবে**

| Flag | কোন alert | Grafana-তে লক্ষণ |
|---|---|---|
| `CHAOS_LATENCY_MS` | HighLatency | `/products/{id}`-এর p95 লাফ; trace-এ handler-এর span লম্বা, DB-র span ছোট |
| `CHAOS_ERROR_RATE` | HighErrorRate | `POST /orders`-এ 5xx; error log; trace-এ DB-তে যাওয়ার আগেই error |
| `CHAOS_MEMORY_LEAK` | PodCrashLooping | worker-এর memory সোজা উপরে, OOMKilled, restart |
| `CHAOS_SLOW_DB` | QueueBacklog | queue বাড়ছে, processing সময় বেড়েছে; trace-এ `pg_sleep` |

**S7-এর সময়সূচি।** Peer-কে session শুরুর সোয়া দুই ঘণ্টা পরের সময় দাও। নিচে T0 মানে load test শুরুর মুহূর্ত।

| সময় | কাজ |
|---|---|
| Session-এর শুরু | `make lab-up` |
| পরের ৯০ মিনিট | মহড়া: dev-এ load চালিয়ে চারটা flag একটা একটা করে; কোন alert কত মিনিটে বাজল আর কোথায় ধরা পড়ল লিখে রাখো |
| T−15 | prod-এ ৫ মিনিট হালকা load; "সুস্থ" dashboard-এর screenshot |
| T−10 | Peer-কে `shoplite-gitops`-এ write access (screenshot); screen recording চালু |
| T−8 | Peer prod-এর values-এ একটা flag চালু করে নিরীহ message দিয়ে একটাই commit করে, শুধু "done" জানায় |
| T−6 | Diff না দেখে CLI দিয়ে prod sync |
| T0 | k6: 20+ RPS, ৪০ মিনিট (প্রথম ১৫ মিনিট প্রশ্নের শর্ত, বাকিটা তদন্ত আর recovery দেখানোর জন্য) |
| T0 → T+20 | শুধু Grafana দিয়ে তদন্ত: alert → dashboard → log → trace |
| T+20 | মূল কারণ ৫ লাইনে লিখে commit (সময়ের প্রমাণ) |
| T+22 | `git pull -q`, `git revert --no-edit HEAD`, push, prod sync |
| T+25 → T+35 | Load চলা অবস্থায় dashboard স্বাভাবিক হচ্ছে: screenshot |
| পরে | RCA শেষ করো, তারপর diff মিলিয়ে দেখো, peer-এর access সরাও |

RCA লেখায় আরও প্রায় ১ ঘণ্টা লাগবে; এটা lab-এর বাইরে করা যায়, কারণ screenshot ততক্ষণে নেওয়া হয়ে গেছে।

**ফাঁদ**

- Load test-এ order-এর হার worker-এর ক্ষমতার ৬০–৭০% রাখো। বেশি হলে chaos ছাড়াই QueueBacklog বাজবে।
- Flag-এর মান খুব ছোট হলে কোনো alert বাজবে না। তাই peer-কে `docs/chaos-menu.md` দাও, যেখানে প্রতিটা flag-এর জন্য অর্থপূর্ণ মান লেখা।
- prod manual sync বলে peer-এর commit নিজে থেকে চালু হয় না; তোমাকেই sync চালাতে হবে, diff না দেখে।
- RCA-তে গতি নয়, যুক্তি আর প্রমাণের মান দেখা হবে। তাড়াহুড়ো কোরো না।

### Phase 10: Docs, শেষ প্রমাণ, demo-র মহড়া (4 ঘণ্টা, S10 আর lab-এর বাইরে)

- দুই repo-র README: কীভাবে চালাবে, evidence index (কোন মার্কের প্রমাণ কোন ফাইলে), deviation log।
- `docs/architecture-diagram.png`, `docs/RCA.md`।
- gitleaks দিয়ে দেখো Git-এ কোনো secret নেই।
- S10-এ: বাদ পড়া প্রমাণ নাও, ১০ মিনিটের demo একবার পুরোটা করে record করো (V7), শেষে `terraform destroy`-এর output রাখো।

## 7. Bonus +10

প্রথম দিন থেকেই দুইটা জিনিস রাখা হচ্ছে যাতে bonus সস্তা হয়: queue-র interface (`QUEUE_BACKEND`) আর Terraform-এ toggle (`cluster_type`, `enable_messaging`)। কাজ শুরু হবে Chaos Day-র পরে, এই ক্রমে।

| Bonus | মার্ক | কী বানাতে হবে | প্রমাণ | কখন |
|---|---|---|---|---|
| B4: SLO, burn-rate | +2 | `POST /orders`-এর SLO (99% request 500 ms-এর মধ্যে, 5xx বাদে); recording rule; দুই জোড়া window-র burn-rate alert (1h ও 5m, 6h ও 30m) | rule ফাইল; Grafana-তে rule; error flag চালিয়ে alert বাজার screenshot | S7-এর শেষে |
| B3: Canary | +2 | `catalog-api`-র জন্য Argo Rollouts; AnalysisTemplate canary pod-এর 5xx হার দেখে, বেশি হলে নিজে থেকে abort | খারাপ version push করার পর auto-abort-এর ভিডিও (V8) | S8 |
| B2: SQS, Lambda | +3 | Terraform `messaging` module; `QUEUE_BACKEND=sqs`; trace context message attribute-এ; order শেষ হলে Lambda একটা `OrderConfirmed` event ছাড়ে | CLI দিয়ে queue-র অবস্থা আর Lambda-র log; order `COMPLETED` | S8 |
| B1: EKS | +3 | Terraform `eks` module; node private subnet-এ; Pod Identity দিয়ে `catalog-api` ও `order-worker` SQS-এ ঢোকে; একই gitops repo দিয়ে পুরো stack | `kubectl get nodes`; Pod Identity association-এর তালিকা; static key ছাড়া SQS call; browser-এ order (V9) | S9 |

**মনে রাখার বিষয়**

- B4 আর B3 হলো RCA-র "preventive measure"-এর বাস্তব রূপ। RCA-তে এদের নাম দিলে গল্পটা সম্পূর্ণ হয়।
- B3 prod-এ চালু করবে Chaos Day-র পরে। আগে চালু থাকলে canary নিজেই peer-এর chaos commit আটকে দেবে।
- B2 আগে k3s-এ চালাও (node-এর IAM role দিয়ে), তারপর B1-এ সেটাই EKS-এ Pod Identity দিয়ে। EKS-এ Pod Identity দিয়ে SQS-এ ঢোকাই B1-এর "AWS access"।
- B2-তে `boto3` যোগ হলে image 150 MB পেরোতে পারে। দরকারি service-এর data ছাড়া বাকিটা বাদ দিতে হবে।
- EKS-এ NetworkPolicy কাজ করাতে VPC CNI-তে সেটা চালু করতে হয়, আর PVC-র জন্য EBS CSI driver লাগে।
- EKS, SQS, Lambda lab-এ চলবে কিনা S1-এর যাচাইয়েই জানা যাবে।

## 8. Bottleneck: কোথায় আটকাতে পারো

| # | সমস্যা | লক্ষণ | সমাধান |
|---|---|---|---|
| 1 | Session শেষে সব মুছে যায় | পরের session-এ কিছু নেই | `make lab-up`; শেষের আগে commit আর প্রমাণ |
| 2 | Lab-এর machine প্রতিবার নতুন | tool নেই, secret নেই | `install-tools.sh`; secret password manager থেকে |
| 3 | Lab-এ IAM, OIDC বা EKS নিষেধ | Terraform-এ AccessDenied | Phase 3-এর যাচাই আর বিকল্পের table |
| 4 | Account, ALB আর ECR-এর ঠিকানা বদলায় | পুরনো image tag বা URL কাজ করে না | `make lab-up` GitHub variable আর gitops values নতুন করে বসায় |
| 5 | Lab বন্ধ অবস্থায় push | pipeline লাল | `LAB_ACTIVE` দিয়ে push ধাপ বাদ |
| 6 | SSM-এ node দেখা যায় না | `TargetNotConnected` | instance profile আর NAT দেখো; boot-এর ২–৩ মিনিট পর চেষ্টা করো |
| 7 | UFW চালুর পর cluster ভাঙে | node NotReady | forward policy ACCEPT; VPC থেকে 6443, 10250, 8472/udp |
| 8 | Docker UFW মানে না (Q3) | "বন্ধ" port বাইরে থেকে খোলা | শুধু 80 বাইরে খোলা, বাকি `127.0.0.1`-এ |
| 9 | sshd-র drop-in ফাইল | config বদলেও password login চলে | `sshd -T` দিয়ে কার্যকর মান দেখো |
| 10 | ECR থেকে image আসে না | `ImagePullBackOff` | node role-এ ECR read আর credential provider; না হলে pull secret |
| 11 | ALB target unhealthy | 503 | SG-তে ALB থেকে NodePort; health check Traefik-এর `/ping`-এ |
| 12 | Non-root-এ Postgres বা Nginx চালু হয় না | permission denied | `fsGroup`, `PGDATA` subfolder, nginx-unprivileged |
| 13 | Image 150 MB পেরোয় | CI-র size check লাল | alpine base, OTLP/HTTP |
| 14 | Pod Pending | node-এ জায়গা নেই | worker t3.large; না হলে request কমাও, dev-এ replica 1 |
| 15 | App-এর metric Prometheus-এ নেই | target তালিকায় নেই | selector-এর setting; Service-এ port-এর নাম |
| 16 | kube-prometheus-stack sync হয় না | "annotations too long" | `ServerSideApply=true` |
| 17 | k3s-এ সবসময় লাল alert | control-plane target down | ওই চারটা scrape বন্ধ |
| 18 | Loki pod Pending | memory request বিশাল | single binary, cache বন্ধ |
| 19 | Exemplar দেখা যায় না | panel-এ বিন্দু নেই | OpenMetrics format, `exemplar-storage`, datasource-এ trace link |
| 20 | Trace দুই টুকরো | API আর worker আলাদা trace | message-এ `traceparent` |
| 21 | Values বদলেও pod বদলায় না | chaos flag কাজ করে না | ConfigMap-এর checksum annotation |
| 22 | ArgoCD আর HPA টানাটানি | replica বারবার বদলায় | HPA থাকলে `replicas` নয় |
| 23 | CI gitops-এ push করতে পারে না | 403 | deploy key |
| 24 | OIDC role নেওয়া যায় না | `AssumeRoleWithWebIdentity` error | trust policy-তে repo আর branch মিলিয়ে দেখো |
| 25 | Trivy হঠাৎ লাল | base image-এ CRITICAL | base image update |
| 26 | Chaos ছাড়াই QueueBacklog | স্বাভাবিক load-এই queue জমে | order-এর হার কমাও, concurrency 4 |
| 27 | Peer পাওয়া যায় না | Q8 আটকে | আজই সময় ঠিক করো |

## 9. প্রমাণ: screenshot আর ভিডিও

**নিয়ম**

- Screenshot: `docs/evidence/qN/NN-নাম.png`। প্রতিটায় terminal-এর prompt বা সময় দেখা যাক।
- `docs/evidence/README.md`-তে একটা table: মার্কের অংশ → কোন ফাইল।
- ভিডিও Git-এ রাখবে না। Drive বা unlisted YouTube-এ তুলে README-তে link দাও।
- Lab-এর resource থাকে না, তাই প্রমাণ সেই session-এই নিতে হবে। পরে আর নেওয়ার সুযোগ নেই।

নিচে V1 থেকে V9 মানে ভিডিও ১ থেকে ৯।

| # | ভিডিও | দৈর্ঘ্য | কোন মার্কের জন্য | কখন |
|---|---|---|---|---|
| V1 | নতুন EC2-তে fresh clone, `make up && make smoke` | ২ মিনিট | Q2 checkpoint | S1 |
| V2 | ALB URL-এ browser থেকে order, `COMPLETED` | ১ মিনিট | Q5 checkpoint | S3 |
| V3 | Alert → dashboard → exemplar → trace → log, ঘড়ি ধরে | ২–৩ মিনিট | Q6 | S5 |
| V4 | Title বদল → push → pipeline → gitops commit → ArgoCD → browser | ৩–৪ মিনিট | Q7 checkpoint | S6 |
| V5 | `kubectl` দিয়ে বদল, ArgoCD ফিরিয়ে আনে | ১ মিনিট | Q7 (d) | S6 |
| V6 | Chaos Day-র পুরো screen recording | পুরোটা | Q8 | S7 |
| V7 | ১০ মিনিটের demo-র মহড়া | ১০ মিনিট | Live demo-র backup | S10 |
| V8 | Canary auto-abort | ২ মিনিট | Bonus 3 | S8 |
| V9 | EKS-এ app, Pod Identity দিয়ে SQS | ২ মিনিট | Bonus 1, 2 | S9 |

প্রতিটা প্রশ্নের screenshot-এর তালিকা ওই phase-এর "প্রমাণ" অংশে আছে।

## 10. দিনের পরিকল্পনা

| দিন | কাজ | ঘণ্টা |
|---|---|---|
| 11 Nov | Phase 0, 1, 2 | 5.0 |
| 12 Nov | S1 | 4.75 |
| 13 Nov | S2, S3 | 8.75 |
| 14 Nov | S4, S5 | 8.0 |
| 15 Nov | S6, S7, RCA লেখা | 9.25 |
| 16 Nov | S8, S9 | 8.5 |
| 17 Nov | S10, docs, form জমা | 4.0 |

কয়েকটা দিন ৮–৯ ঘণ্টার। কোনো দিন পিছিয়ে গেলে প্রথমে S9 (EKS) বাদ দাও, তারপর S8, আর S10 ও docs 16 Nov-এ টেনে আনো। Deadline-এর দিনে শুধু শেষ যাচাই থাকলে সবচেয়ে নিরাপদ।

## 11. ১০ মিনিটের live demo

Demo-র আগে: ৪৫ মিনিট আগে `make lab-up`, load test চলছে, সব tab খোলা, V7 হাতের কাছে।

| সময় | কাজ |
|---|---|
| 0:00 | Title বদলের commit push করো; pipeline চলতে থাকুক |
| 0:30 – 2:30 | Diagram ধরে architecture |
| 2:30 – 4:30 | Load চলা অবস্থায় Golden Signals dashboard |
| 4:30 – 6:30 | Exemplar থেকে trace, trace থেকে log |
| 6:30 – 7:30 | `kubectl` দিয়ে বদল, ArgoCD-র self-heal |
| 7:30 – 9:00 | Pipeline শেষ, gitops commit, ArgoCD sync, browser-এ নতুন title |
| 9:00 – 10:00 | প্রশ্নের উত্তর |

Pipeline শুরুতেই চালু করার কারণ: ওটা শেষ হতে ৫–৭ মিনিট লাগে।

## 12. জমা দেওয়ার আগে checklist

- [ ] দুই repo-র structure প্রশ্নের tree-র সাথে মেলে।
- [ ] Fresh clone-এ `make up && make smoke` pass করে।
- [ ] Git-এ কোনো credential, key বা password নেই।
- [ ] Evidence index সম্পূর্ণ, প্রতিটা মার্কের অংশের প্রমাণ আছে।
- [ ] Architecture diagram আর ১–২ পৃষ্ঠার RCA আছে।
- [ ] README-তে deviation log আছে।
- [ ] Peer-এর write access সরানো হয়েছে।
- [ ] `terraform destroy`-এর output রাখা আছে।
- [ ] Form জমা হয়েছে, 17 Nov-এর আগে।

**Deviation log-এ যা লিখবে**

- Kubernetes node-এ UFW: cluster-এর ভেতরের port শুধু VPC থেকে খোলা।
- Node-এ Q3-এর 3.1, 3.2 আর 3.4 বসানো; backup service শুধু Q3-এর server-এ।
- prod manual sync, তাই self-heal dev-এ দেখানো।
- State lock S3-এর নিজস্ব lock ফাইল দিয়ে।
- k3s-এর সাথে আসা containerd ব্যবহার করা হয়েছে।
- Product seed হয় Postgres-এর init script দিয়ে।
- dev দেখা যায় ALB-র port 8080-এ।
- Lab-এ যা করা যায়নি (যেমন Budget), প্রমাণ সহ।

## 13. শুরু করার আগে যা ঠিক করতে হবে

1. Submission form-এ ঠিক কী কী চায়।
2. Lab-এ দিনে কয়টা session নেওয়া যায়, আর session শেষে resource থাকে কিনা।
3. S1-এর lab যাচাইয়ের ফলাফল। এর উপর SSM, OIDC আর bonus-এর পথ ঠিক হবে।
4. Q8-এর peer আর সময়।
5. Live demo কবে।
6. Domain আছে কিনা। থাকলে Route 53 record আর HTTPS যোগ হবে।
7. `shoplite-app` আর `shoplite-gitops` repo তৈরি।

## সূত্র

- [Ingress NGINX Retirement (kubernetes.io)](https://kubernetes.io/blog/2025/11/11/ingress-nginx-retirement/)
- [Ingress NGINX: Statement from the Steering and Security Response Committees](https://www.kubernetes.io/blog/2026/01/29/ingress-nginx-statement/)
- [Promtail end-of-life (Grafana docs)](https://grafana.com/docs/loki/latest/clients/promtail/)
- [Promtail থেকে Alloy-তে migration](https://grafana.com/docs/alloy/latest/set-up/migrate/from-promtail/)
- [Loki chart-এর community repo-তে যাওয়া](https://grafana.com/docs/loki/next/setup/upgrade/upgrade-to-community.md)
- [Trivy GitHub Actions supply chain compromise (Snyk)](https://snyk.io/articles/trivy-github-actions-supply-chain-compromise)
