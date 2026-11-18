# ShopLite: কাজের অগ্রগতি (progress log)

শেষ আপডেট: 2026-11-18, shoplite-app-এর README (`04b7063`); আগে Q8-এর lab-এর পদ্ধতি, RCA-র কাঠামো, আর architecture diagram `shoplite-app/docs`-এ (`a641940`)। Deadline: 17 Nov 2026।

প্রতিটা step শেষ হলে এই ফাইল আপডেট হবে। বিস্তারিত পরিকল্পনা [PLAN.md](PLAN.md)-তে, প্রশ্নপত্র [project.md](project.md)-তে।

অন্য PC-তে কাজ চালাতে: [OFFICE-PC-GUIDE.md](OFFICE-PC-GUIDE.md)। Claude-এর কাজের নিয়ম: [CLAUDE.md](CLAUDE.md)।

**মূল নিয়ম (12 Nov):** প্রশ্নে যা চাওয়া, শুধু সেটুকুই বানানো হবে। সুবিধার জন্য বাড়তি tool বা feature যোগ হবে না। সময় লাগলেও কোনো কিছু কাটছাঁট করা হবে না।

চিহ্ন: ✅ শেষ ও push হয়েছে · 🟡 আংশিক · ⬜ বাকি

## 1. এক নজরে

| প্রশ্ন | বিষয় | মার্ক | অবস্থা |
|---|---|---|---|
| Q1 | Application | 8 | ✅ ৯টা step-এর সবগুলো শেষ |
| Q2 | Docker | 10 | ✅ চারটা অংশই শেষ; নতুন clone-এ `make up && make smoke` pass করেছে (WSL Ubuntu)। Lab-এর নতুন EC2-তে প্রমাণ (ভিডিও V1) বাকি |
| Q3 | Linux server | 5 | 🟡 `linux/` ফাইল তৈরি, local Ubuntu 24.04 test server-এ চারটা কাজই রিহার্সাল করা; server বানানোর Terraform-ও তৈরি (4.6); lab-এর EC2-তে চালিয়ে screenshot নেওয়া বাকি |
| Q4 | Terraform, Ansible | 17 | 🟡 Code আর lab-এর পদ্ধতি সব শেষ (4.1–4.8): Terraform, Ansible-এর hardening আর k3s cluster (local-এ ৩টা node-এ রিহার্সাল করা), lab-এর সংযোগ (SSM-এর ভেতর দিয়ে SSH, inventory, ECR), আর `docs/evidence/q4/commands.md`; বাকি শুধু lab-এ চালানো আর screenshot |
| Q5 | Kubernetes, Helm | 15 | 🟡 Code শেষ (5.1–5.3): chart-এ পাঁচটা workload, non-root, requests আর limits, Secret আর ConfigMap, PDB, HPA, Ingress, NetworkPolicy; Traefik ALB-র পেছনে (NodePort, `/ping`); local k3s-এ dev আর prod দুটোই চলে, order `COMPLETED`। 5.4-এ lab-এর পদ্ধতি (`docs/evidence/q5/commands.md`, repo ভাগ সহ)। বাকি শুধু lab-এ চালানো |
| Q6 | Observability | 25 | 🟡 Code আর lab-এর পদ্ধতি শেষ (6.1–6.5): metrics (kube-prometheus-stack, ServiceMonitor, exemplar), Loki, Alloy (JSON parse), Tempo (OTLP), Grafana-য় log ↔ trace আর exemplar → trace, "ShopLite — Golden Signals" dashboard, ৫টা alert আর runbook, Alertmanager → Slack, k6-এর load test, `docs/evidence/q6/commands.md`; সব ArgoCD দিয়ে, local k3s-এ রিহার্সাল pass। বাকি শুধু lab-এ চালানো |
| Q7 | CI/CD, GitOps | 10 | 🟡 Code আর lab-এর পদ্ধতি শেষ (7.1–7.8): shoplite-gitops (root app, dev auto-sync আর self-heal, prod manual), cluster-এর bootstrap আর ArgoCD, GitHub OIDC-এর দুই role (CI-র push, PR-এর read-only plan), main pipeline (lint, test, build, Trivy-র gate, ECR, gitops-এ tag), PR pipeline আর Terraform plan-এর comment, `promote`, `docs/evidence/q7/commands.md`; সব local-এ রিহার্সাল করা। দুই repo GitHub-এ ভাগ হয়েছে (17 Nov, `publish-repos.sh`)। বাকি lab-এ চালানো |
| Q8 | Chaos, RCA | 10 | 🟡 chaos flag-এর code (Step 7); lab-এর পদ্ধতি `docs/evidence/q8/commands.md` আর RCA-র কাঠামো `docs/RCA.md` (`a641940`, section 7b)। বাকি lab-এ exercise, তারপর RCA লেখা |
| Bonus | EKS, SQS, canary, SLO | +10 | ⬜ |

**মোট কয়টা step:** Q1 ভাঙা হয়েছে ৯টা step-এ, Q2 প্রশ্নের চারটা অংশে (নিচে)। পুরো project-এ ৮টা প্রশ্ন আর ৪টা bonus। Q3 থেকে বাকিগুলোর code নিজের PC-তে লেখা হবে, চালানো আর প্রমাণ নেওয়া হবে AWS lab-এ।

## 2. Q1-এর ৯টা step

| # | Step | অবস্থা | Commit |
|---|---|---|---|
| 1 | Skeleton আর database | ✅ | `04ad552` |
| 2 | catalog-api core: config, JSON log, `/products`, `/products/{id}`, `/healthz`, `/readyz` | ✅ | `04ad552` |
| 3 | `POST /orders`, `GET /orders/{id}` | ✅ | `fd89722` |
| 4 | order-worker, graceful SIGTERM | ✅ | `3ede8c1` |
| 5 | ৬টা Prometheus metric | ✅ | `225269e` |
| 6 | OpenTelemetry tracing, queue দিয়ে trace context | ✅ | `2a33e9c` |
| 7 | ৪টা chaos flag | ✅ | `161c225` |
| 8 | Unit test (কমপক্ষে ৫টা API test) | ✅ প্রতিটা step-এর সাথে লেখা; এখন API ৪৮, worker ২৯, আর web image-এর ১৫টা check | সব commit-এ |
| 9 | web: Nginx + HTML/JS (product তালিকা, order, status) | ✅ | `eb46deb` |

### প্রতিটা step-এ কী হলো আর কীভাবে যাচাই হলো

**Step 1: Skeleton আর database**
- `shoplite-app/` আর `shoplite-gitops/` folder। পরে আলাদা repo হিসেবে push হবে।
- `init.sql`: `products` আর `orders` table, ১২টা product। দ্বিতীয়বার চালালেও duplicate হয় না।
- Compose-এ Postgres 16 আর Redis 7.4, healthcheck সহ। Postgres-এর data `pgdata` named volume-এ।
- `.gitattributes` সব ফাইলকে LF রাখে, কারণ Windows-এ `core.autocrlf=true` আছে।

**Step 2: catalog-api core**
- FastAPI, Python 3.12 alpine image, user `uid=10001` (root না)।
- সব config env থেকে আসে। Log প্রতি লাইনে এক JSON: `timestamp, level, service, message, trace_id`।
- যাচাই: 200, 404, 422 ঠিক আসে; Redis বন্ধ করলে `/readyz` 503 দেয়।

**Step 3: Orders API**
- আগে DB-তে `PENDING` order commit, তারপর `LPUSH orders:pending`, তারপর 201।
- Queue-তে push ব্যর্থ হলে order `FAILED` হয় আর API 503 দেয়।
- যে product নেই তাতে 404; ভুল body-তে 422।

**Step 4: order-worker**
- ৪টা consumer: `BRPOP` → `PROCESSING` → ১–২ সেকেন্ড কাজ (০.২ সেকেন্ড আসল CPU) → `COMPLETED`।
- SIGTERM পেলে হাতে থাকা order শেষ করে তবে বন্ধ হয়। যাচাই: ৮টা order দিয়ে মাঝপথে stop করা হলো; ৪টা শেষ হলো, ৪টা queue-তে রইল, worker আবার চালু হলে সেগুলোও শেষ হলো।

**Step 5: Metrics**
- catalog-api `:8000/metrics`: `http_requests_total`, `http_request_duration_seconds`, `orders_created_total`, `order_queue_depth`।
- order-worker `:8001/metrics`: `orders_processed_total{result}`, `order_processing_seconds`।
- `route` label-এ থাকে template (`/products/{id}`), আসল path না।

**Step 6: Tracing**
- একটা order = এক trace, দুই service জুড়ে ৭টা span:

```text
catalog-api   POST /orders               server
  catalog-api   INSERT orders              client
  catalog-api   send orders:pending        producer
    order-worker  process orders:pending     consumer
      order-worker  UPDATE orders              client
      order-worker  simulate work              internal
      order-worker  UPDATE orders              client
```

- Queue-র message-এ `traceparent` যায়; worker সেখান থেকে একই trace চালিয়ে যায়।
- দুই service-এর log-এ একই `trace_id`। Latency histogram-এর exemplar-এ আসল `trace_id`।
- তখন local-এ trace দেখা হয়েছিল Jaeger দিয়ে। প্রশ্নে নেই বলে Q2-তে সেটা সরানো হয়েছে; trace দেখা হবে Q6-এ Tempo + Grafana দিয়ে।

**Step 7: Chaos flag (Q1.5)**
- চারটা flag, সবগুলো default বন্ধ। মান পড়া আর যাচাই হয় `config.py`-তে; ভুল মান দিলে service চালুই হয় না।

| Flag | কোথায় | কী করে | Grafana/trace-এ কীভাবে ধরা পড়বে |
|---|---|---|---|
| `CHAOS_LATENCY_MS` | catalog-api, `app/faults.py` | ~30% `GET /products/{id}`-এ ওই কয় ms দেরি, DB query-র আগে | p95 লাফ দেয়; trace-এ server span লম্বা, DB span ছোট, শুরুতে ফাঁক |
| `CHAOS_ERROR_RATE` | catalog-api, `app/faults.py` | ওই ভাগ `POST /orders`-এ 500, DB ছোঁয়ার আগেই | 5xx বাড়ে; ERROR log; trace-এ একটাই span, INSERT নেই |
| `CHAOS_MEMORY_LEAK` | order-worker, `processor.py` | প্রতি processed order-এ 1 MiB ধরে রাখে, কখনো ছাড়ে না | worker-এর memory সোজা উপরে ওঠে, শেষে OOMKilled আর restart |
| `CHAOS_SLOW_DB` | order-worker, `store.py` | প্রতিটা UPDATE-এর আগে `SELECT pg_sleep(2)` | queue জমে; `order_processing_seconds` বাড়ে; trace-এ 2 s-এর `SELECT` span |

- Log, error-এর body বা span-এর নামে কোথাও flag-এর নাম বা মান নেই। দুই service-এর test-এ এটা যাচাই করা আছে।
- যাচাই, তখনকার Jaeger সহ আসল stack-এ:
  - Latency 500 ms: server-এর histogram অনুযায়ী ৪৪০টার মধ্যে ১৩৪টা (৩০.৫%) 0.5 s-এর বেশি। Trace-এ DB span শুরু হয় +500.9 ms-এ, চলে 0.8 ms।
  - Error rate 0.3: ১০০টা order-এ ২৫টা 500, DB-তে ঠিক ৭৫টা নতুন row। ব্যর্থ trace-এ শুধু 0.4 ms-এর একটা ERROR span। ২৫টা ERROR log, প্রতিটায় `trace_id`।
  - Slow DB: order শেষ হয় 5.4 s-এ (স্বাভাবিক 1.2–2.1 s)। Trace-এ প্রতিটা UPDATE-এর আগে ~2000 ms-এর `SELECT pg_sleep(2)`। ৪২টা order-ই 5–7.5 s-এর bucket-এ।
  - Memory leak: ৪০টা order-এ worker-এর RSS 50.0 থেকে 90.9 MiB (প্রতি order-এ ~1.02 MiB)।
  - সব flag বন্ধ করলে আবার স্বাভাবিক: order 1.8–2.1 s, RSS 48 MiB। সব log মিলিয়ে "chaos" শব্দ একবারও নেই।

**Step 9: web**
- `services/web/`: Nginx-এর উপর একটা static page (`public/`)। Product-এর তালিকা দেখায়, order নেয়, প্রতি সেকেন্ডে status দেখে যতক্ষণ না `COMPLETED` বা `FAILED` হয়। ID দিয়ে order খোঁজা যায়, আর API-র error (404, 500) বার্তা হিসেবে দেখায়।
- Page-এর সব call যায় `/api/...`-তে। Nginx সেটা catalog-api-তে পাঠায়, `/api` অংশ বাদ দিয়ে, query রেখে।
- Image: `nginxinc/nginx-unprivileged:1.30.6-alpine`, uid 101, port 8080, `HEALTHCHECK`, unpack করা size 64.6 MB। Stage: `test` (image-এর check) → `runtime`। Step 9-এ একটা `builder` stage page-এ version বসাত; প্রশ্নে নেই বলে Q2-তে সেটা সরানো হয়েছে।
- Log প্রতি লাইনে JSON, অন্য দুই service-এর মতো একই পাঁচটা field (`trace_id` null, কারণ nginx-এ trace নেই)। 5xx হলে ERROR, 4xx হলে WARNING; `/healthz` log হয় না।
- যাচাই:
  - Test stage-এ তখন ১৬টা check pass (version-এর check সরানোর পর এখন ১৫টা)। ইচ্ছা করে ভুল upstream দিলে proxy-র check FAIL করে, exit 1।
  - Web-কে compose-এর network-এ চালিয়ে browser থেকে: ১২টা product, order #145 আর #146 1.2–1.7 s-এ `COMPLETED`, ID দিয়ে খোঁজা কাজ করে, না-থাকা order-এ 404-এর বার্তা।
  - `CHAOS_ERROR_RATE=1` দিলে page দেখায় "Could not place the order (HTTP 500: internal server error)"। JavaScript-এর কোনো error নেই।
  - ফোনের মাপে (375 px) page পাশে scroll করে না; Stock column লুকিয়ে যায়।
  - Upstream-এর নাম না মিললেও nginx healthy থাকে, page 200, `/api` 502।
  - ১৪টা access log লাইনের সবগুলো বৈধ JSON। CPU limit 1 দিলে worker process ১টা।

## 3. Q2: Docker

| অংশ | মার্ক | কী আছে | অবস্থা |
|---|---|---|---|
| (a) Dockerfile | 4 | তিনটা service: multi-stage, non-root (web 101, বাকি দুইটা 10001), `HEALTHCHECK`, `.dockerignore`, প্রতিটা image 150 MB-এর নিচে | ✅ `6c68826` |
| (b) Compose | 3 | পাঁচটা component, Postgres-এর data `pgdata` named volume-এ, health-check-ভিত্তিক `depends_on` | ✅ `6c68826` |
| (c) Smoke test | 2 | `scripts/smoke-test.sh` | ✅ `6c68826` |
| (d) Makefile | 1 | `build up down test smoke` | ✅ `6c68826` |

**কী হলো**
- Compose-এ web যোগ হয়েছে। বাইরে খোলা শুধু web (`${WEB_PORT:-80}:8080`), আর সেটা চালু হয় catalog-api healthy হওয়ার পর। বাকি চারটা service শুধু compose-এর network-এ থাকে।
- প্রশ্নে নেই বলে সরানো হয়েছে: Jaeger, compose-এর OTEL endpoint, catalog-api-র host port 8000, web-এর version footer আর heading-এ `<title>` copy করা।
- API আর worker-এর virtualenv-এ এখন নিজের pip নেই; base image-এর pip `--python` দিয়ে সেখানে package বসায়। Size:

| Image | Unpack করা size | `docker images`-এর DISK USAGE |
|---|---|---|
| web | 64.6 MB | 90 MB |
| catalog-api | 109.2 MB | 142 MB (আগে 159) |
| order-worker | 88.0 MB | 114 MB (আগে 132) |

- `scripts/smoke-test.sh` এই ধাপগুলো চালায়:
  1. Stack চালু করে।
  2. Web দিয়ে `/api/readyz` 200 না দেওয়া পর্যন্ত অপেক্ষা করে (সর্বোচ্চ 120 s)।
  3. একটা order দেয় (`product_id` 1, quantity 2)।
  4. প্রতি সেকেন্ডে status দেখে, `COMPLETED` না হওয়া পর্যন্ত (সর্বোচ্চ 60 s)।

  কোনো ধাপ ব্যর্থ হলে, order `FAILED` হলে বা সময় পেরোলে exit 1। শুধু `curl` আর `sed` লাগে, `jq` না। Web-এর port নেয় compose থেকে (`docker compose port web 8080`)।
- `Makefile`-এর target:
  - `build`
  - `up`: build, চালু, healthy পর্যন্ত অপেক্ষা
  - `down`: container বন্ধ, data volume থাকে
  - `test`: তিন service-এর test stage
  - `smoke`

  `.env` না থাকলে `.env.example` থেকে একবার বানিয়ে নেয়।
- যাচাই:
  - **আসল `make` দিয়ে (WSL Ubuntu 24.04):** `make test`-এ web-এর ১৫টা check, API-র ৪৮টা আর worker-এর ২৯টা test pass। `make up && make smoke`-এ order 148 `COMPLETED`।
  - **নতুন clone, যেন পরিষ্কার machine:** আগে `.env` ছিল না, project নাম আলাদা, database নতুন। `make up && make smoke` pass করেছে। `.env` example থেকে তৈরি হয়েছে, ১২টা product seed হয়েছে, order 1 `COMPLETED`। তারপর পরীক্ষার container, volume আর clone মুছে ফেলা হয়েছে।
  - **ব্যর্থ হলে:** `CHAOS_ERROR_RATE=1` দিলে smoke test দেখায় `FAIL: POST /orders answered HTTP 500`, আর `make` দেয় exit 1।
  - **চালু stack:** পাঁচটা container healthy। Host-এ খোলা শুধু web, port 8000-এ কিছু নেই। App container-এর user 101/10001/10001। `depends_on` তিনটাই `service_healthy`। Postgres-এর data `shoplite_pgdata` volume-এ।
  - **Browser:** compose-এর web-এ ১২টা product, order #149 1.3 s-এ `COMPLETED`, footer নেই।

## 4. Q3: Linux server

| অংশ | মার্ক | ফাইল | অবস্থা |
|---|---|---|---|
| 3.1 Users, SSH | 1.5 | `linux/sshd_config`; user আর group-এর command `evidence/commands.md`-এ | 🟡 code আর রিহার্সাল `3019a9a`; lab-এ screenshot বাকি |
| 3.2 Permission | 1 | command আর 777-এর উত্তর `evidence/commands.md`-এ | 🟡 একই |
| 3.3 Backup | 1.5 | `linux/systemd/`: service, timer, script | 🟡 একই |
| 3.4 Firewall | 1 | `linux/firewall/ufw.sh` | 🟡 একই |

**কী হলো**
- `linux/sshd_config`: `PermitRootLogin no`, `PasswordAuthentication no`, `KbdInteractiveAuthentication no` (PAM দিয়েও password বন্ধ), `PubkeyAuthentication yes`। বাকিটা হুবহু Ubuntu 24.04-এর default।
- `linux/systemd/`:
  - `shoplite-backup.sh`: compose-এর postgres container-এর ভেতরে `pg_dump` চালায়, আর ফলাফল লেখে `/var/backups/shoplite/shoplite-<সময়>.sql`-এ। ফাইল শুধু root পড়তে পারে।
  - `shoplite-backup.service`: `Restart=on-failure`, ব্যর্থ হলে ৫ মিনিট পর আবার চেষ্টা, এক ঘণ্টায় সর্বোচ্চ ৩ বার।
  - `shoplite-backup.timer`: প্রতি রাত 02:00।
- `linux/firewall/ufw.sh`: default deny incoming; শুধু 22, 80, 443 খোলা।
- `linux/evidence/commands.md`: lab-এ কোন command কোন ক্রমে চালাতে হবে, কী output আসা উচিত, কোন screenshot নিতে হবে (`00` থেকে `10`), আর 777 কেন ভুল তার এক লাইনের উত্তর। Q2-এর পরিষ্কার machine-এর checkpoint-ও শুরুতে আছে।

**রিহার্সাল (এই PC-তে, Docker-এর ভেতরে):** systemd সহ একটা অস্থায়ী Ubuntu 24.04 "server", আর "অন্য machine" হিসেবে আরেকটা container। `commands.md`-এর command প্রায় হুবহু চালানো হয়েছে; শেষে দুইটা container আর তাদের image মুছে ফেলা হয়েছে।
- **3.1:** `sshd_config.d/`-এ ইচ্ছা করে এমন একটা ফাইল রাখা হয়েছিল, যা root আর password login চালু করে। তবু আমাদের ফাইল বসানোর পর `sshd -T` দেখায় `permitrootlogin no`, `passwordauthentication no`। Key দিয়ে deploy-এর login হয়। Password দিয়ে চেষ্টা করলে `Permission denied (publickey)`। Root-কে বৈধ key দিলেও `Permission denied`, আর log-এ `ROOT LOGIN REFUSED`।
- **3.2:** folder `drwxr-s---+ root ops`। নতুন ফাইল নিজে থেকেই `-rw-r----- root:ops`। `deploy` পড়তে পারে, `nobody` আর `ubuntu` পারে না।
- **3.3:** `systemd-analyze verify`-এ কোনো error নেই। Timer `active (waiting)`, পরের চালানো 02:00। একটা backup-এ দুইটা table আর ১২টা product। Postgres বন্ধ রেখে চালালে service ব্যর্থ হয়; postgres ফিরলে systemd নিজেই আবার চালায়, আর backup লেখা হয়। অর্ধেক লেখা কোনো ফাইল থাকে না।
- **3.4:** UFW active, default deny। ভেতরে program শুনছে এমন port 8000-ও বাইরে থেকে timeout হয়। Port 22 খোলা। Firewall চালুর পরেও SSH চলে।

**Lab-এ বাকি:** Ubuntu 24.04 EC2-তে `commands.md` ধরে চালানো আর screenshot নেওয়া। Security group-এ 8000 খোলা রাখতে হবে, যাতে প্রমাণ হয় আটকাচ্ছে UFW।

## 5. Q4: Terraform আর Ansible

AWS-এর credential শুধু lab-এ থাকে। তাই এখানে code লেখা হয় আর যাচাই হয় `terraform test` দিয়ে, mock provider ব্যবহার করে; এটা AWS account ছাড়াই module-এর logic পরীক্ষা করে। আসল `apply` হবে lab-এ।

| Step | কাজ | প্রশ্নের অংশ | অবস্থা |
|---|---|---|---|
| 4.1 | State bucket (`terraform/bootstrap`), S3 backend lock সহ, সব resource-এ `project=shoplite`, USD 20-এর Budget | (e) remote state, Cost guard | ✅ `d690cb5` |
| 4.2 | `network` module: দুই AZ, ২টা public আর ২টা private subnet, IGW, NAT Gateway | (a), (f) | ✅ `6733b56` |
| 4.3 | `compute` module: node-এর security group, SSM-এর IAM role, ৩টা EC2 private subnet-এ | (b), (c), (f) | ✅ `bd07fcf` |
| 4.4 | `alb` module: public subnet-এ ALB, Kubernetes ingress-এ forward | (d), (f) | ✅ `2d9d0fc` |
| 4.5 | `ecr` module: তিনটা image repo | (e), (f) | ✅ `9e1c75e` |
| 4.6 | `terraform/q3-server`: Q3-এর EC2 | Q3-এর server | ✅ `5a0b220` |
| 4.7a | Ansible-এর ভিত আর `hardening` role (Q3-এর 3.1, 3.2, 3.4 প্রতিটা node-এ) | (g) | ✅ `4f4a286` |
| 4.7b | `container_runtime`, `k3s_server`, `k3s_agent`, `kubeconfig` role | (g) | ✅ `f862f1d` |
| 4.7c | Lab-এর সংযোগ: SSM-এর ভেতর দিয়ে SSH (node-এ key), inventory, ECR থেকে image টানা | (c), (g) | ✅ `d85bb48`, `135b8ea` |
| 4.8 | Lab-এ চালানোর পদ্ধতি (`docs/evidence/q4/commands.md`) | সব | ✅ `5cc1286` |

**Step 4.1-এ কী হলো**
- `terraform/bootstrap/`: state রাখার S3 bucket, নাম `shoplite-tfstate-<account id>-<region>`। এর versioning চালু, যাতে state নষ্ট হলে আগেরটা ফেরানো যায়। `force_destroy` দেওয়া, যাতে শেষে `terraform destroy` ভরা bucket-ও মুছতে পারে। এর নিজের ছোট state local-এ থাকে; যে bucket এখনো তৈরিই হয়নি, তাতে তার নিজের state রাখা যায় না।
- `terraform/backend.tf`: S3 backend, key `shoplite/terraform.tfstate`, `use_lockfile = true`। Terraform চলার সময় state-এর পাশে একটা `.tflock` ফাইল রাখে, তাই দুইজন একসাথে state বদলাতে পারে না। DynamoDB লাগে না। Bucket আর region দেওয়া হয় `init`-এর সময়, কারণ bucket-এর নামে account id থাকে।
- `terraform/main.tf`:
  - Terraform ≥ 1.10, AWS provider `~> 6.73` (lock ফাইলে ঠিক 6.73.0)।
  - Provider-এর `default_tags` দিয়ে প্রতিটা resource-এ `project=shoplite`।
  - মাসিক USD 20-এর cost Budget: আসল খরচ 100% (মানে USD 20) পেরোলে email যায়।
- `terraform/variables.tf`: `region` (lab-এর preflight-এর আগ পর্যন্ত `ap-southeast-1`) আর `budget_alert_email`। Email-টা যাচাই করা হয় আর কখনো Git-এ যায় না; দেওয়া হয় `TF_VAR_budget_alert_email` দিয়ে। `.gitignore`-এ `*.tfvars` যোগ হয়েছে।
- Test: bucket-এর ৩টা, budget-এর ২টা।

**যাচাই** (`hashicorp/terraform:1.17.2`, Docker-এ):
- `fmt` পরিষ্কার, `validate` ঠিক, ৫টা test pass।
- Budget 25 করলে test fail করে।
- আসল backend দিয়ে `init` চালালে থামে শুধু credential না থাকায়, অর্থাৎ backend-এর setting ঠিক আছে।

**Lab-এ বাকি:** bootstrap আর মূল configuration `apply`; tag দিয়ে resource খোঁজার output; budget দেখা; শেষে `destroy`।

**Step 4.2-এ কী হলো** (`terraform/modules/network/`)
- VPC `10.0.0.0/16`, DNS support আর hostname চালু।
- দুইটা public subnet (`10.0.0.0/24`, `10.0.1.0/24`) আর দুইটা private (`10.0.10.0/24`, `10.0.11.0/24`)। প্রতিটা ধরনের i-তম subnet i-তম AZ-এ, তাই VPC দুই AZ জুড়ে। কোনো subnet নিজে থেকে public IP দেয় না।
- Internet Gateway। Public route table: `0.0.0.0/0` → IGW, দুই public subnet-এর জন্য।
- NAT Gateway একটাই, Elastic IP সহ, প্রথম public subnet-এ। Private route table: `0.0.0.0/0` → NAT, দুই private subnet-এর জন্য। ফলে node-গুলো বাইরে যেতে পারে (image, SSM, update), কিন্তু বাইরে থেকে node-এ ঢোকার পথ নেই।
- Name tag (`shoplite-vpc`, `shoplite-public-a`, ...)। Variable-এর validation: প্রতি ধরনের কমপক্ষে দুইটা subnet, আর দুই ধরনের সংখ্যা সমান।
- Output: `vpc_id`, `vpc_cidr`, `azs`, `public_subnet_ids`, `private_subnet_ids`। মূল configuration-এ `module "network"` বসানো হয়েছে, আর `outputs.tf` VPC ও subnet-এর id দেখায়।

**যাচাই:**
- Module-এ ৭টা test, মূল configuration-এ ৩টা, bootstrap-এ ৩টা, সব pass। Module-এর test-এ দেখা হয়: subnet আর AZ, IGW-এর route, NAT-এর route, নাম, তিন AZ-এও চলে কিনা, এক AZ আর অসমান তালিকা বাতিল হয় কিনা।
- ইচ্ছা করে private subnet-এর route IGW-তে পাঠালে NAT-এর test fail করে।

**Step 4.3-এ কী হলো** (`terraform/modules/compute/`)
- **Security group (`security.tf`), least privilege:**
  - Internet থেকে কোনো rule নেই, SSH (22)-ও না। Admin access SSM দিয়ে, যার agent শুধু বাইরে connect করে।
  - Node-এর group-এ শুধু ৩টা port, আর শুধু অন্য node-এর জন্য: 8472/udp (Flannel VXLAN, pod network), 10250/tcp (kubelet), 9100/tcp (node-exporter, Q6)।
  - আলাদা control-plane group-এ 6443/tcp (k3s API), শুধু node-গুলোর জন্য।
  - বাইরে যাওয়া খোলা, NAT দিয়ে।
  - ALB থেকে ingress port-এ ঢোকার rule আসবে `alb` module-এর সাথে (4.4)।
- **IAM role (`main.tf`):** শুধু EC2 নিতে পারে। এতে ঠিক দুইটা AWS policy: `AmazonSSMManagedInstanceCore` (SSM) আর `AmazonEC2ContainerRegistryPullOnly` (ECR থেকে শুধু image টানা, push নয়)। সাথে instance profile।
- **Node:** Ubuntu 24.04 (Canonical-এর সর্বশেষ image)। একটা control-plane `t3.medium`, দুইটা worker `t3.large`, সব private subnet-এ। Worker-গুলো দুই AZ-এ ভাগ করা।
  - Public IP নেই।
  - IMDSv2 বাধ্যতামূলক, hop limit 1, যাতে container node-এর credential পড়তে না পারে।
  - Encrypted 30 GiB gp3 disk।
  - `role` tag (control-plane/worker), Ansible-এর inventory-র জন্য।
- **Output:** instance id (SSM-এর target), private IP (agent-রা join করবে), node-এর security group id (alb module-এর জন্য)। মূল configuration-এ `module "compute"` বসানো হয়েছে।

**যাচাই:**
- Compute-এর ৭টা test pass। মূল configuration-এ এখন ৪টা; সব মিলিয়ে Terraform-এর ২১টা test pass।
- ইচ্ছা করে node-গুলোর মধ্যে SSH খুললে, বা worker-কে public IP দিলে, test fail করে।

**Step 4.4-এ কী হলো** (`terraform/modules/alb/`)
- **ALB:** internet-facing Application Load Balancer, দুই AZ-এর public subnet-এ, নিজের security group সহ।
- **Listener (প্রতি environment-এ একটা):** port 80 → prod, Traefik-এর NodePort 30080। Port 8080 → dev, NodePort 30081; Q7-এর auto-sync হওয়া dev browser-এ দেখাতে এটা লাগে।
- **Target group:** দুইটা worker-ই আছে। Health check Traefik-এর `/ping`-এ, 200 আশা করে।
- **Security group-এর শিকল:** internet → ALB শুধু 80 আর 8080। ALB → শুধু node-এর group-এ, শুধু ওই দুইটা NodePort-এ। Node-এর group এই NodePort নেয় শুধু ALB থেকে।
- **Route 53 record নেই,** কারণ domain নেই। ALB-র DNS নামই URL।
- **Output:** `dns_name`, `urls` (prod `http://<alb>`, dev `http://<alb>:8080`), security group, target group। মূল configuration-এ `app_urls` output।
- **Validation:** NodePort 30000–32767-এর মধ্যে, প্রতিটা listener-এর আলাদা port, কমপক্ষে দুইটা subnet।

**যাচাই:**
- ALB-র ৮টা test pass। মূল configuration-এ এখন ৫টা; Terraform-এর মোট ৩০টা test pass।
- ইচ্ছা করে prod-এর listener dev-এর target group-এ পাঠালে test fail করে।

**Q5-এর জন্য মনে রাখতে হবে:** Traefik default-এ `/ping` দেয় নিজের আলাদা port-এ (9000), web port-এ নয়। Traefik বসানোর সময় web entrypoint-এও `/ping` চালু করতে হবে, নইলে ALB-র target unhealthy হবে। দুইটা উপায়: `ping.manualRouting` আর `/ping`-এর জন্য একটা IngressRoute, অথবা health check-এর path variable (`health_check_path`) বদলানো।

**Step 4.5-এ কী হলো** (`terraform/modules/ecr/`)
- তিনটা repository: `shoplite/web`, `shoplite/catalog-api`, `shoplite/order-worker`। নাম local image-এর নামের সাথে মেলে।
- `force_delete`, যাতে শেষের `terraform destroy` image থাকা অবস্থাতেও repo মুছতে পারে।
- প্রশ্নে চাওয়া হয়নি বলে নেই: scan-on-push (scan হবে Q7-এ Trivy দিয়ে), পুরনো image মোছার নিয়ম, immutable tag। Encryption AWS-এর default।
- Output:
  - `repository_urls` আর `repository_arns`, ছোট নাম ধরে। ARN লাগবে Q7-এ CI-এর role-কে শুধু এই repo-তে push-এর অনুমতি দিতে।
  - `registry`, `docker login`-এর host।
- মূল configuration-এ `ecr_repository_urls` আর `ecr_registry` output।
- Validation: কমপক্ষে একটা নাম, কোনো নাম দুইবার নয়, আর ECR-এর নামের নিয়ম (ছোট হাতের অক্ষর)।

**যাচাই:**
- ECR-এর ৪টা test pass। মূল configuration-এ এখন ৬টা; Terraform-এর মোট ৩৫টা test pass।
- `force_delete` বন্ধ করলে test fail করে।

এই step-এর সাথে প্রশ্নের চাওয়া চারটা module-ই (`network`, `compute`, `alb`, `ecr`) তৈরি হলো: 4(f)-এর code দিক পূর্ণ।

**Step 4.6-এ কী হলো** (`terraform/q3-server/`)

Q3-এর server-ও Terraform দিয়ে বানানো হবে, কারণ console শুধু billing দেখার জন্য।
- **নিজের ছোট VPC** (user-এর সিদ্ধান্ত, 12 Nov): `10.1.0.0/16`, একটা public subnet, Internet Gateway আর তার route। NAT নেই। Default VPC বা মূল configuration-এর উপর নির্ভর করে না, তাই Q4-এর বড় infra-র আগেই বানানো যায়।
- **Server:** একটা Ubuntu 24.04 `t3.medium`, public IP সহ। IMDSv2, encrypted 20 GiB gp3 disk। SSH key pair বানানো হয় admin-এর public key থেকে।
- **Security group:** শুধু admin-এর address থেকে 22, 80, 443, আর 3.4-এর পরীক্ষার port 8000। বাইরে যাওয়া খোলা।
- **State:** একই state bucket, আলাদা key `q3-server/terraform.tfstate`, lock সহ।
- **`admin_cidr`:** /24 বা তার চেয়ে ছোট হতে হবে, কখনো `0.0.0.0/0` নয়। এটা আর `ssh_public_key` যাচাই করা হয়, আর আসে শুধু `TF_VAR_` দিয়ে।
- **Output:** `public_ip`, `ssh`, `instance_id`।
- **`linux/evidence/commands.md`:** শুরুতে নতুন অংশ "0.1 Create the server" (bootstrap, init, apply, ssh-এর command), আর শেষে "After grading" (destroy)।

**যাচাই:**
- q3-server-এর ৭টা test pass; Terraform-এর মোট ৪২টা test pass।
- ইচ্ছা করে inbound rule `0.0.0.0/0`-এ খুললে test fail করে।

**Step 4.7a-এ কী হলো** (`ansible/`)
- **Version:** `requirements.txt` pin করে ansible-core 2.21.6; এটা Python 3.12-এ চলে এমন সর্বশেষ version, আর lab-এর Ubuntu 24.04-এ Python 3.12। `requirements.yml` pin করে ansible.posix 2.2.2 আর community.general 14.0.1।
- **Playbook:** `ansible.cfg`, আর `site.yml` group `control_plane`, `workers` আর দুইটা মিলে `k3s_cluster`।
- **`roles/hardening`:** Q3-এর 3.1, 3.2, 3.4, প্রতিটা node-এ। 3.3 (backup) শুধু Q3-এর server-এ, কারণ node-এ Compose-এর Postgres নেই।
  - `ops` group আর `deploy` user। deploy-এর key optional।
  - `linux/sshd_config` সরাসরি সেই ফাইল থেকেই। বসানোর আগে `sshd -t` দিয়ে যাচাই, বদল হলে handler ssh restart করে।
  - `/var/log/shoplite`: `root:ops 2750`, সাথে একটা default ACL rule।
  - UFW: incoming বন্ধ, outgoing খোলা, আর 22/80/443 খোলা, ঠিক `linux/firewall/ufw.sh`-এর মতো।
- **Node-এর ব্যতিক্রম (`group_vars`):**
  - VPC থেকে 8472/udp, 10250 আর 9100।
  - Control-plane-এ VPC থেকে 6443।
  - k3s-এর pod আর service network (`10.42.0.0/16`, `10.43.0.0/16`) থেকে সব। k3s-এর docs-এ UFW-এর জন্য এটাই বলা।
  - Forward করা traffic চলতে দেওয়া (pod আর NodePort-এর জন্য, PLAN Phase 5)।
- **`tests/` (local রিহার্সাল, শুধু Docker লাগে):**
  - `node.Dockerfile`: EC2 node-এর মতো systemd আর sshd সহ Ubuntu 24.04।
  - `controller.Dockerfile`: pin করা Ansible।
  - `inventory.ini`, `verify.yml`।
  - `run.sh`: ৩টা node চালু করে, `site.yml` দুইবার চালায় (দ্বিতীয়বার `changed=0` বাধ্যতামূলক), যাচাই চালায়, সত্যিকারের connection আর login পরীক্ষা করে, শেষে সব মুছে ফেলে।

**যাচাই** (`bash ansible/tests/run.sh`, এক মিনিটের মতো):
- প্রথম run-এ প্রতিটা node-এ `changed=11`, দ্বিতীয় run-এ `changed=0`। মানে idempotent; প্রশ্নের full-marks শর্ত "idempotent Ansible"।
- `verify.yml` তিন node-এ pass।
- VPC-র ভেতর থেকে 10250 খোলা। যে port-এর অনুমতি নেই, তাতে program শুনলেও আটকে যায়।
- deploy key দিয়ে ঢুকতে পারে; root আর key ছাড়া login প্রত্যাখ্যাত।
- ইচ্ছা করে প্রতিবার "changed" দেখানো একটা task ঢোকালে `run.sh` fail করে।

**Step 4.7b-এ কী হলো** (`ansible/roles/`, বাসার PC-তে)
- **`container_runtime`:** k3s-এর containerd থাকে k3s binary-র ভেতরেই (PLAN-এর সিদ্ধান্ত)। তাই প্রশ্নের "install the container runtime" মানে এখানে:
  - Kernel module `overlay` আর `br_netfilter`। কোনোটা আগে থেকে থাকলে modprobe চলে না। Reboot-এর পরেও load হয় (`/etc/modules-load.d/k3s.conf`)।
  - Sysctl: `net.ipv4.ip_forward`, `net.bridge.bridge-nf-call-iptables`, `net.bridge.bridge-nf-call-ip6tables`, তিনটাই 1।
  - Pin করা k3s binary (`v1.37.2+k3s1`), GitHub release থেকে। Release-এর checksum ফাইলের sha256 না মিললে বসে না। Download ধীর হলে 60 সেকেন্ড অপেক্ষা, ৩ বার পর্যন্ত আবার চেষ্টা।
  - `kubectl`, `crictl`, `ctr` k3s-এর দিকে link।
  - `tasks/verify.yml`: k3s চালু হওয়ার পরে containerd-কে version জিজ্ঞেস করে ছাপায় (রিহার্সালে `containerd 2.3.7-k3s1`)।
- **`k3s_server`:**
  - `/etc/rancher/k3s/config.yaml`: k3s-এর নিজের Traefik বন্ধ, pod আর service network, kubeconfig শুধু root পড়তে পারে। ফাইলটার mode `0600`।
  - systemd unit, k3s-এর install script যেমন লেখে তেমন।
  - চালু করে অপেক্ষা করে: API-র `/readyz`, join token তৈরি হওয়া, node `Ready`।
- **`k3s_agent`:**
  - Join token প্রতিবার চলমান server থেকে পড়ে; কখনো Git-এ যায় না।
  - Server-এর private IP আর token config-এ (`0600`)।
  - Join করে, control-plane থেকে দেখে node `Ready` হওয়া পর্যন্ত অপেক্ষা করে।
- **`kubeconfig`:** control-plane-এর `/etc/rancher/k3s/k3s.yaml` আনে Ansible চালানো machine-এ, `ansible/kubeconfig`-এ (`0600`, Git-এ যায় না)। API-র ঠিকানা `https://127.0.0.1:6443`, কারণ kubectl চলবে SSM port-forward দিয়ে (4.7c)।
- **`site.yml`:** hardening → container_runtime → k3s_server → k3s_agent → containerd যাচাই → kubeconfig। একটা node fail করলে পুরো run থামে (`any_errors_fatal`)।
- **`.gitignore`:** `kubeconfig*` pattern `roles/kubeconfig` folder-কেও লুকিয়ে ফেলছিল; role-টা আলাদা করে ফিরিয়ে আনা হয়েছে।

**যাচাই** (`bash ansible/tests/run.sh`; বাসার PC-তে প্রায় ১০ মিনিট, বেশিটা download):
- প্রথম run-এ তিন node-ই সফল (cp1-এ `changed=21`, worker-এ `changed=20`)। দ্বিতীয় run-এ তিনটাতেই `changed=0`।
- `verify.yml` তিন node-এ pass:
  - kernel setting, k3s-এর version, config ফাইলের mode `0600`, service চালু;
  - তিনটা node `Ready`;
  - k3s-এর নিজের Traefik নেই, CoreDNS আর metrics-server আছে।
- UFW চালু অবস্থাতেই cluster কাজ করে:
  - CoreDNS চলে, মানে pod চলে আর image নামে।
  - metrics-server তিন node-এরই CPU আর memory পড়ে। এর জন্য pod থেকে অন্য node-এর kubelet-এ (10250) পৌঁছাতে হয়। Q5-এর HPA এর ওপর নির্ভর করে।
- আনা kubeconfig দিয়ে অন্য machine থেকে API-তে পৌঁছানো যায় (test-এ worker1 থেকে)।
- রিহার্সালে ধরা পড়ে ঠিক হওয়া সমস্যা:
  - GitHub download-এর 10 সেকেন্ডের timeout।
  - cp1 fail করার পরেও worker-রা join করতে এগোচ্ছিল।
  - এই PC-র Docker-এর cgroup v1 (section 12)।
  - `.gitignore` role লুকাচ্ছিল।
- নতুন cluster check-গুলো ইচ্ছা করে ভাঙিয়ে দেখা হয়নি, কারণ প্রতিটা run-এ ১০ মিনিট লাগে। তবে development-এর সময় সেগুলো সত্যিকারের ভুল ধরেছে: node register না হওয়া, version না পাওয়া।

**Lab-এ বাকি (4.7c, 4.8):** SSM-এর ভেতর দিয়ে SSH, lab-এর inventory, ECR থেকে image টানা; তারপর আসল EC2-তে চালানো, `kubectl get nodes`-এ ৩টা `Ready`-এর screenshot।

**Q5-এর জন্য মনে রাখতে হবে:**
- k3s-এর `servicelb` চালু আছে। Traefik-এর Service `LoadBalancer` হলে servicelb node-এর 80/443 port দখল করবে, তাই Traefik-এর chart-এ Service type `NodePort` (30080/30081) দিতে হবে।
- ALB থেকে NodePort-এর traffic UFW-এর ভেতর দিয়ে আসে কিনা lab-এ দেখতে হবে। Forward policy ACCEPT থাকায় আসার কথা।

**Step 4.7c-এ কী হলো** (lab-এর সংযোগ, বাসার PC)

*Terraform (`d85bb48`):*
- **Node-এ SSH key:** compute module-এ key pair `shoplite-nodes`, প্রতিটা node-এ বসে। Public key আসে শুধু `TF_VAR_ssh_public_key` দিয়ে। Security group-এ port 22 আগের মতোই বন্ধ, node-এর public IP-ও নেই।
- **SSM-এর ভেতর দিয়ে SSH কীভাবে চলে:** Ansible-এর ssh একটা `ProxyCommand` চালায়: `aws ssm start-session ... --document-name AWS-StartSSHSession`। SSM agent instance-এর ভেতর থেকেই port 22-এ যুক্ত করে দেয়। তাই internet বা VPC থেকে 22 খোলার দরকার পড়ে না।
- **Output `ansible_inventory`** (`terraform/templates/inventory.ini.tftpl`): control-plane আর দুই worker, instance id দিয়ে, `site.yml`-এর group-এ (`control_plane`, `workers`, `k3s_cluster`); user `ubuntu`; key `~/.ssh/shoplite` (variable `ssh_private_key_file`); ProxyCommand-এ region সহ। Lab-এ প্রতি apply-এর পরে লেখা হবে `ansible/lab.ini`-এ (Git-এ যায় না)।
- **Output `kubectl_tunnel`:** SSM port-forward, local 6443 → control-plane-এর 6443। আনা kubeconfig-এর `127.0.0.1:6443` ঠিক এটাই।

*Ansible (`135b8ea`):*
- **ECR থেকে image টানা:** `container_runtime` role kubelet-এর image credential provider বসায়। Plugin: `ecr-credential-provider v1.37.0` (kubernetes/cloud-provider-aws, Kubernetes 1.37-এর সাথে মেলে), artifacts.k8s.io থেকে, sha256 মিলিয়ে। Config বলে: `*.dkr.ecr.*.amazonaws.com`-এর যেকোনো image-এর জন্য এই plugin।
  - Plugin token নেয় node-এর IAM role দিয়ে (`AmazonEC2ContainerRegistryPullOnly`)। কোনো pull secret বা access key কোথাও রাখা নেই।
  - k3s server আর agent-এর `config.yaml` kubelet-কে plugin-এর দিকে দেখায়।
- **চলমান node-এ বদল:** k3s binary বা plugin বদলালে k3s/k3s-agent restart হয়। নইলে আবার চালালেও পুরনোটাই চলত। কিছু না বদলালে কিছুই হয় না (দ্বিতীয় run-এ `changed=0`)।

**যাচাই:**
- Terraform-এর ৪৭টা test pass: compute ৯ (key সব node-এ, key না হলে বাতিল), root ৯ (inventory, tunnel, key না হলে বাতিল), বাকিগুলো আগের মতো।
- ইচ্ছা করে একটা worker-এর `key_name` বাদ দিলে compute-এর test fail করে।
- Render করা inventory দিয়ে Ansible দুইটা test node-এ command চালিয়েছে, ProxyCommand-এর ভেতর দিয়ে। `aws`-এর জায়গায় ছিল একটা নকল script, যা node-এর port 22-এ যুক্ত করে। ssh তাকে দিয়েছে ঠিক lab-এর মতো argument: `--target <ansible_host> ... --parameters portNumber=22`। মানে inventory-র quoting ঠিক আছে। আসল SSM দেখা যাবে শুধু lab-এ।
- Ansible-এর রিহার্সাল pass: প্রথম run সফল, দ্বিতীয় run-এ `changed=0`। `verify.yml` plugin-এর version আর k3s-এর setting দেখে।
- ECR-এর মতো নামের image দিয়ে worker1-এ pod চালালে kubelet `ecr-credential-provider` চালায়। Log-এ আসে: `error execing credential provider plugin ecr-credential-provider for image 123456789012.dkr.ecr...`। Test-এ AWS role নেই, তাই fail করাই প্রত্যাশিত। Lab-এ node-এর role থাকায় এখানে token পাওয়া যাবে।

**Lab-এ যা লাগবে:** 4.8-এর document-এ লেখা আছে (নিচে)।

**Step 4.8-এ কী হলো** (`docs/evidence/q4/commands.md`, `5cc1286`)

Lab-এ Q4 চালানোর পুরো পদ্ধতি, ইংরেজিতে (grader পড়বেন), Q3-এর `linux/evidence/commands.md`-এর ধরনে। Screenshot-গুলো এই folder-এই রাখা হবে।
- **0.1–0.4, প্রস্তুতি:**
  - clone;
  - lab-এর machine-এ tool: Terraform 1.17.2, AWS CLI v2, Session Manager plugin, kubectl 1.37.2, pin করা Ansible আলাদা venv-এ। প্রতিটা download-এর SHA-256 মেলানো হয়।
  - region, budget-এর email আর SSH key, শুধু `TF_VAR_` দিয়ে;
  - lab-এ `t3.medium`/`t3.large` পাওয়া যায় কিনা দেখা, আর না পেলে PLAN-এর বিকল্প।
- **1–3, চালানো:** bootstrap → backend সহ `init` → `apply` → `ansible_inventory` থেকে `ansible/lab.ini` → SSM-এ তিনটা node `Online` হওয়া পর্যন্ত অপেক্ষা → `site.yml` দুইবার → দ্বিতীয় terminal-এ `kubectl_tunnel` → `kubectl get nodes`।
- **4, প্রমাণ:** 4a থেকে 4g আর cost guard-এর প্রতিটার জন্য command, কী দেখা উচিত, আর screenshot-এর নাম (`01-...png` থেকে `21-...png`)। দুটো জিনিস আলাদা করে বলা:
  - **State lock দেখানো:** এক terminal-এ `apply` approval-এর প্রশ্নে অপেক্ষা করে, অন্য terminal-এ S3-এ `terraform.tfstate.tflock` দেখা যায় আর `plan` থামে `Error acquiring the state lock`-এ।
  - **ALB-র target `healthy` হয় Q5-এর Traefik বসার পরে,** তাই ওই screenshot Q5-এর পরে।
- **After grading:** আগে q3-server (একই state bucket), তারপর মূল configuration, শেষে bucket।

**যাচাই** (lab ছাড়া যতটুকু সম্ভব):
- Tool-এর পুরো ধাপ হুবহু একটা নতুন `ubuntu:24.04` container-এ চালানো হয়েছে। সব বসেছে, checksum মিলেছে: Terraform 1.17.2, aws-cli 2.40.2, Session Manager plugin 1.2.896.0, kubectl 1.37.2, ansible-core 2.21.6, ansible.posix 2.2.2, community.general 14.0.1।
- ১৮টা `--query` AWS-এর API-র আকারের নমুনা data-য় চালানো হয়েছে (jmespath 1.0.1, AWS CLI এটাই ব্যবহার করে)। সব ঠিক ফল দিয়েছে। একটা ভুল ধরা পড়ে ঠিক হয়েছে: `join`-এর লেখায় বৈধ JSON ছিল না।
- ২২টা `aws` command credential ছাড়া চালানো হয়েছে। প্রতিটা শুধু `Unable to locate credentials`-এ থেমেছে, মানে argument-এর syntax ঠিক।
- এই পরীক্ষাতেই ধরা পড়েছে, AWS CLI v1 `AWS_REGION` পড়ে না। তাই document `AWS_DEFAULT_REGION`-ও export করে।
- যা যাচাই করা যায়নি: আসল AWS-এর উত্তর, আর lab-এর machine সত্যিই Ubuntu কিনা।

## 6. Q5: Kubernetes আর Helm

একটা chart (`helm/shoplite`), environment প্রতি একটা release আর namespace: prod `shoplite`, dev `shoplite-dev` (PLAN)। Code নিজের PC-তে লেখা হয়, যাচাই হয় local-এর একটা k3s-এ (`helm/tests/run.sh`); lab-এ চলবে ArgoCD দিয়ে (Q7)।

| Step | কাজ | প্রশ্নের অংশ | অবস্থা |
|---|---|---|---|
| 5.1 | Chart-এর কাঠামো, পাঁচটা workload, Secret আর ConfigMap, local রিহার্সাল | (a), (b), (e) | ✅ `9fa4aeb` |
| 5.2 | catalog-api-র PDB, order-worker-এর HPA, ALB-র পেছনে Traefik, Ingress `/` আর `/api` | (a), (d) | ✅ `14e4bd0` |
| 5.3 | NetworkPolicy: Postgres আর Redis-এ শুধু catalog-api আর order-worker | (c) | ✅ `f367f76` |
| 5.4 | Lab-এ চালানোর পদ্ধতি (`docs/evidence/q5/commands.md`), checkpoint | সব | ✅ `04305e8` (lab-এ চালানো বাকি) |

**Step 5.1-এ কী হলো** (`helm/shoplite/`)
- **পাঁচটা workload, প্রশ্নের table মেনে:**
  - **web:** Deployment, ২টা replica, Service। Nginx-এর `/api/` proxy-র ঠিকানা পুরো নামে (`catalog-api.<namespace>.svc.cluster.local:8000`), কারণ nginx-এর resolver search domain মানে না।
  - **catalog-api:** Deployment, ২টা replica, liveness `/healthz`, readiness `/readyz` (DB আর Redis-এ পৌঁছায় কিনা), Service।
  - **order-worker:** Deployment, `replicas` লেখা নেই, কারণ 5.2-এর HPA সংখ্যাটা ঠিক করবে। Git-এ সংখ্যা থাকলে ArgoCD আর HPA টানাটানি করত। `terminationGracePeriodSeconds: 30`, liveness `/healthz` (8001)।
  - **postgres:** StatefulSet, PVC (`volumeClaimTemplates`, 1Gi), headless Service। Seed হয় `files/init.sql` থেকে, Compose-এর সেই একই ফাইল, ConfigMap দিয়ে। `PGDATA` একটা subfolder-এ, কারণ নতুন disk-এর root খালি থাকে না (EBS-এ `lost+found`)।
  - **redis:** Deployment, শুধু ClusterIP Service।
- **Security (5a):** প্রতিটা pod image-এর নিজের non-root user-এ চলে: app দুটো 10001, web 101, Postgres 70, Redis 999। সাথে `runAsNonRoot`, seccomp `RuntimeDefault`, privilege escalation বন্ধ, সব capability বাদ।
- **Resources (5a):** প্রতিটা container-এ CPU আর memory-র requests আর limits। Dev-এর মান prod-এর চেয়ে হালকা, কারণ dev একই cluster-এ prod আর monitoring-এর সাথে চলে।
- **Secret আর ConfigMap (5b):**
  - DB-র user আর password থাকে Secret `shoplite-db`-এ। Chart Secret বানায় না, শুধু নাম ধরে পড়ে (`database.existingSecret`)। Secret বানানো হয় cluster-এ, chart বসানোর আগে, তাই Git-এ কখনো plain-text secret থাকে না।
  - App-এর setting থাকে ConfigMap `shoplite-config`-এ: log level, DB আর Redis-এর ঠিকানা, worker-এর concurrency, OTLP endpoint (Q6-এর জন্য ফাঁকা), environment, chaos flag।
  - catalog-api আর order-worker-এর pod template-এ ConfigMap-এর checksum থাকে। তাই কোনো setting বদলালে pod নতুন হয়; Q8-এর chaos flag এর ওপর নির্ভর করে।
- **Values (5e):** `values.yaml` (default), `values-dev.yaml`, `values-prod.yaml`। Image হয় `<registry>/shoplite/<service>:<tag>`; registry আর tag lab-এ আসবে shoplite-gitops থেকে (Q7)।
- **`helm/tests/run.sh`:** local রিহার্সাল (নিচে)।

**যাচাই** (`bash helm/tests/run.sh`, প্রায় ৫ মিনিট):
- k3s v1.37.2 (lab-এর version) Docker-এ চালু হয়। তিনটা image build করে সরাসরি cluster-এ ঢোকানো হয়, registry লাগে না।
- `helm lint --strict`, dev আর prod দুই values-এ। Render করা prod-এর প্রতিটা manifest আসল API server-এ server-side dry run-এ গৃহীত।
- Secret আগে বানিয়ে dev-এর values দিয়ে install করার পর:
  - সব pod `Ready`।
  - প্রতিটা container uid 0 নয়: 10001, 101, 70, 999।
  - প্রতিটা container-এ requests আর limits আছে।
  - Postgres-এ ১২টা product।
  - web-এর ভেতর দিয়ে দেওয়া order (web → catalog-api → Postgres + Redis → order-worker) `COMPLETED` হয়।
  - একটা setting বদলালে catalog-api আর order-worker নতুন pod পায়, web পায় না (web ConfigMap পড়ে না)।
- দুইবার চালানো হয়েছে, দুইবারই pass। প্রথমবারের পর শেষ check-টা শক্ত করা হয়েছে: আগে প্রথম pod-এর hash দেখত, যেটা তখনো বন্ধ হতে থাকা পুরনো pod-ও হতে পারত। এখন Deployment-এর `generation` দেখে।
- "requests বা limits নেই" ধরার regex আলাদা করে নমুনা লাইনে পরীক্ষা করা হয়েছে: শুধু অসম্পূর্ণ লাইনগুলো ধরে।

**Lab-এ বাকি:** ECR-এর image দিয়ে চালানো, আর ALB-র URL-এ browser থেকে order (checkpoint, ভিডিও V2)।

**Step 5.2-এ কী হলো** (`14e4bd0`; সিদ্ধান্ত দুটো user-এর, 14 Nov: Traefik-এর setting PLAN অনুযায়ী shoplite-gitops-এ, আর worker-এর HPA প্রশ্নের মতো ১ থেকে ৪, dev-এও)
- **PodDisruptionBudget (catalog-api):** `minAvailable: 1`। Node drain বা upgrade-এর মতো স্বেচ্ছায় বাধার সময় একবারে একটার বেশি catalog-api pod সরানো যায় না, তাই অন্তত একটা সবসময় চলে।
- **HorizontalPodAutoscaler (order-worker):** `autoscaling/v2`, CPU-ভিত্তিক, ১ থেকে ৪ replica। লক্ষ্য CPU request-এর 70%; প্রতিটা order worker-এর প্রায় 0.2 s CPU খায়।
- **Traefik** (`shoplite-gitops/apps/traefik.yaml`): ArgoCD-র একটা Application, যাতে আছে Traefik-এর নিজের chart (42.2.0, Traefik v3.7.16) আর তার সব setting।
  - Service `NodePort`, কারণ ALB নির্দিষ্ট NodePort-এ পাঠায়। `LoadBalancer` হলে k3s-এর servicelb node-এর 80 আর 443 দখল করত।
  - দুইটা entrypoint: `web` → NodePort 30080 (prod, ALB-র port 80), `dev` → 30081 (dev, ALB-র port 8080)। HTTPS নেই, কারণ domain নেই।
  - ALB-র health check-এর জন্য `/ping` দুই entrypoint-এই, chart-এর নিজের `ingressRoute.healthcheck` দিয়ে। Traefik-এর নিজের probe ভেতরের entrypoint-এই থাকে।
  - requests আর limits।
- **Ingress** (`templates/ingress.yaml`): দুইটা Ingress, `ingressClassName: traefik`।
  - web: path `/`।
  - catalog-api: path `/api`, Traefik-এর `StripPrefix` middleware দিয়ে, কারণ catalog-api `/products` চেনে, `/api/products` নয়। Middleware পুরো Ingress-এ বসে, তাই দুইটা আলাদা Ingress।
  - Domain নেই, তাই environment আলাদা হয় Traefik-এর entrypoint দিয়ে: prod `web`, dev `dev` (values থেকে)।

**যাচাই** (`bash helm/tests/run.sh`, এখন প্রায় ১০ মিনিট):
- Traefik বসে gitops-এর ফাইল থেকেই: chart, version আর values `yq` দিয়ে পড়া হয়। Lab-এ ArgoCD যা বসাবে, রিহার্সালে হুবহু সেটাই চলে।
- dev (`shoplite-dev`) আর prod (`shoplite`) দুটোই বসে। 5.1-এর সব check দুই namespace-এই pass।
- দুই NodePort-এই `/ping` 200, `/`-এ page, `/api`-তে catalog-api।
- NodePort 30080-এ দেওয়া order `COMPLETED` হয়েছে আর গেছে শুধু prod-এর database-এ। 30081-এরটা গেছে dev-এ।
- একসাথে ৪০০টা order দিলে worker-এর CPU 138%/70%, HPA worker ১ থেকে ২-তে নিয়েছে।
- `kubectl drain` প্রতিটা environment থেকে একটা catalog-api pod সরিয়েছে, দ্বিতীয়টা PDB আটকেছে (`Cannot evict pod as it would violate the pod's disruption budget`)। এই সময়েও prod-এর API সাড়া দিয়েছে।

**Step 5.3-এ কী হলো** (`templates/networkpolicy.yaml`, `f367f76`)
- **দুইটা NetworkPolicy, `postgres` আর `redis`** (PLAN অনুযায়ী)। প্রতিটা নিজের pod বাছাই করে, আর ঢুকতে দেয় শুধু একই namespace-এর catalog-api আর order-worker-কে, নিজের port-এ।
- কোনো pod-কে একটা NetworkPolicy বাছাই করলে, অনুমতি নেই এমন সব আসা traffic বাদ পড়ে। তাই web, অন্য যেকোনো pod, আর অন্য environment-এর namespace (যেমন dev থেকে prod-এর database) সবাই আটকায়।
- Postgres আর Redis-এর probe চলে pod-এর ভেতরে (exec), তাই এতে আটকায় না।

**যাচাই** (রিহার্সাল, k3s নিজেই NetworkPolicy মানে):
- Pod-এর ভেতর থেকে `nc` দিয়ে সংযোগ:
  - catalog-api আর order-worker → `postgres:5432` আর `redis:6379`: খোলে।
  - web → দুটোই আটকায়।
  - dev-এর catalog-api → prod-এর `postgres.shoplite...` আর `redis.shoplite...`: আটকায়।
- Order আগের মতোই `COMPLETED`; 5.1 আর 5.2-এর সব check আবার pass (এবার HPA worker ১ থেকে ৩-এ নিয়েছে)।
- একই `nc` allowed pod থেকে সংযোগ পায় আর web থেকে পায় না। তাই আটকানোটা নিয়মের কারণেই, `nc` বা DNS-এর সমস্যায় নয়।

**Step 5.4-এ কী হলো** (`04305e8`): lab-এ Q5 চালানোর পদ্ধতি, `shoplite-app/docs/evidence/q5/commands.md`, grader-এর জন্য ইংরেজিতে। আগে 7.5 (`promote`) বানানো হয়েছে, যাতে prod Git দিয়েই image পায় (section 7)।
- **একবারই, প্রথম session-এর আগে (section 0):**
  - **দুই repo:** `git subtree split` দিয়ে history সহ ভাগ।
    - shoplite-app-এ force push হবে, তাতে `test.md` বদলে যাবে (user-এর সিদ্ধান্ত)। shoplite-gitops নতুন বানাতে হবে।
    - দুটোই public, কারণ ArgoCD credential ছাড়া পড়ে।
    - পরে shoplite-app-এর বদল আবার split করে `--force` ছাড়া push করা যায়। shoplite-gitops বদলাতে হবে তার নিজের clone-এ।
  - **GitHub-এর setting:**
    - deploy key, write access সহ, shoplite-gitops-এ;
    - তার private key shoplite-app-এর secret `GITOPS_DEPLOY_KEY`-এ, তারপর ফাইল দুটো মুছে ফেলা;
    - `AWS_REGION`, শুধু region আলাদা হলে।
- **প্রতি session-এ:**
  1. দুই repo পাশাপাশি clone, তারপর Q4-এর পদ্ধতি 0.2 থেকে 3।
  2. Helm 4.3.1 (checksum দেখে); GitHub-এ `AWS_ROLE_ARN` আর `LAB_ACTIVE=true`।
  3. main-এর "Run workflow": ECR-এ image, gitops-এ dev-এর tag। এটা চলতে চলতেই পরের ধাপ।
  4. `scripts/bootstrap-cluster.sh`: ArgoCD, তারপর ArgoCD নিজে Traefik আর dev বসায়।
  5. promote-এর "Run workflow", তারপর ArgoCD-র UI-তে shoplite-prod-এ REFRESH → SYNC → SYNCHRONIZE।
  6. প্রমাণ (a)–(e) আর checkpoint: browser-এ ALB-র URL-এ order `COMPLETED` (ভিডিও V2), আর prod-এর database-এ তার row। মোট ১৯টা screenshot।
  7. শেষে `LAB_ACTIVE=false`, তারপর Q4-এর destroy।
- **Q4-এর পদ্ধতি:** clone-এর ধাপ এখন দুই repo clone করে। ভাগের আগে devops-final।

**যাচাই** (AWS আর GitHub ছাড়া):
- ✅ নতুন `ubuntu:24.04`-এ Helm-এর block: checksum `OK`, `helm version` v4.3.1। নষ্ট ফাইলে checksum fail করে।
- ✅ দুটো `aws` command credential ছাড়া থামে শুধু `Unable to locate credentials`-এ (AWS CLI 2.40.3)। দুটো `--query` jmespath 1.0.1-এ নমুনা ডেটায় ঠিক ফল দেয়।
- ✅ **Repo ভাগ**, একটা container-এ monorepo-র clone আর দুটো bare repo নিয়ে ("GitHub"; shoplite-app-এ placeholder `test.md`):
  - ৬৩টা commit থেকে shoplite-app পায় ২৮টা (12 Nov থেকে), shoplite-gitops পায় ৬টা, এক সেকেন্ডে।
  - force push-এর পরে `test.md` আর তার commit নেই। দুই repo-র main split branch-এর সাথে মেলে।
  - একই split আবার করলে একই commit আসে। পরের একটা বদল `--force` ছাড়াই push হয় (fast-forward)।
- ✅ **kubectl-এর command:** GitOps রিহার্সালের একটা copy (cleanup বন্ধ, self-heal-এর ধাপ বাদ) local k3s-এ ArgoCD বসিয়েছে। ArgoCD নিজে Traefik, dev আর prod বসিয়েছে।
  - পদ্ধতির section 5 আর 6-এর সব bash block markdown থেকে হুবহু তুলে "lab machine"-এ (bash, kubectl, helm, curl) চালানো হয়েছে। প্রতিটার output লেখার সাথে মেলে:
    - পাঁচটা workload, HPA `cpu: 5%/70%` (1–4), probe `/healthz` আর `/readyz`, PDB, grace period 30;
    - PVC `Bound`, ১২টা product;
    - সব pod-এ requests আর limits; uid 10001, 101, 70, 999, কোথাও 0 নয়;
    - Secret-এর শুধু key আর byte; ConfigMap; Secret-এর reference;
    - NetworkPolicy: catalog-api আর order-worker খোলা, web বন্ধ (web → catalog-api খোলা), dev → prod-এর database বন্ধ;
    - `/ping` 200; `helm lint` দুই values-এ; Application-এর chart আর values ফাইল;
    - database-এ order `COMPLETED`।
  - Section 3 আর 4-এর kubectl-এর check-ও চলেছে (dev-এর curl NodePort 30081-এ)। শেষে container, network আর অস্থায়ী ফাইল মোছা হয়েছে।
- ⏳ Lab-এ চালানো: GitHub-এর দুই workflow, ArgoCD-র UI, ALB, browser-এর checkpoint। আর ALB থেকে NodePort-এ যাওয়া UFW-এর routed allow পার হয় কিনা।

## 6b. Q6: Observability

Stack বসে lab-এ ArgoCD দিয়ে, namespace `monitoring`-এ (প্রশ্ন)।
- প্রতিটা chart-এর setting থাকে shoplite-app-এর `monitoring/stack/`-এ, কারণ প্রশ্ন বলে monitoring configuration shoplite-app-এ।
- ArgoCD-র Application থাকে shoplite-gitops-এর `apps/`-এ।
- যাচাই হয় GitOps-এর রিহার্সালে: local k3s-এ ArgoCD নিজে Git থেকে বসায়।

| Step | কাজ | প্রশ্নের অংশ | অবস্থা |
|---|---|---|---|
| 6.1 | Metrics: kube-prometheus-stack (Prometheus, Alertmanager, Grafana, node-exporter, kube-state-metrics); catalog-api আর order-worker-এর ServiceMonitor; exemplar storage; Grafana ALB-র `/grafana`-এ | (a), (b) | ✅ `cb6830f` (lab-এ চালানো বাকি) |
| 6.2 | Logs আর traces: Loki, Alloy (JSON parse), Tempo (OTLP); Grafana-তে log ↔ trace আর exemplar → trace | (a), (d) | ✅ `289ea11` (lab-এ চালানো বাকি) |
| 6.3 | "ShopLite — Golden Signals" dashboard, JSON Git-এ | (c) | ✅ `cadd840` (lab-এ চালানো বাকি) |
| 6.4 | ৫টা alert (severity, `runbook_url`), ৫টা runbook, Alertmanager → Slack | (e) | ✅ `9e65283` (lab-এ চালানো বাকি) |
| 6.5 | Lab-এর পদ্ধতি `docs/evidence/q6/commands.md`, আর k6-এর load test | সব | ✅ `4f4002e` (lab-এ চালানো বাকি) |

**Chart-এর version** (16 Nov বাছা; দুই সপ্তাহের বেশি পুরনো সর্বশেষ release):
- kube-prometheus-stack **92.17.0**, prometheus-community থেকে। এতে Prometheus Operator v0.94.2, Prometheus v3.15.1, আর Grafana chart 14.3.0।
- loki **20.2.1** (Loki 3.7.9) আর tempo **3.2.1** (Tempo 3.1.1), দুটোই **grafana-community** থেকে। grafana-র নিজের `loki` chart এখন Enterprise Logs-এর, আর তার `tempo` chart deprecated।
- alloy **1.15.0** (Alloy v1.21.3), grafana থেকে।

**Step 6.1-এ কী হলো** (`cb6830f`)
- **`shoplite-gitops/apps/kube-prometheus-stack.yaml`:** ArgoCD-র Application, namespace `monitoring`।
  - Sync wave 0, Traefik-এর সাথে, কারণ ShopLite-এর ServiceMonitor (wave 1)-এর CRD এখান থেকে আসে।
  - দুই source: chart আসে prometheus-community থেকে, values আসে shoplite-app থেকে (`ref: app`)।
  - `ServerSideApply`, কারণ Prometheus Operator-এর CRD বড়।
- **`shoplite-app/monitoring/stack/kube-prometheus-stack.yaml`:** chart-এর values।
  - k3s-এর control plane-এর অংশগুলো (controller-manager, scheduler, proxy, etcd) scrape হয় না। k3s এগুলো এক process-এ চালায়, আলাদা করে পাওয়া যায় না।
  - chart-এর default rule আর dashboard বন্ধ। Alert থাকবে শুধু আমাদের ৫টা (6.4), dashboard শুধু আমাদেরটা (6.3)।
  - Prometheus cluster-এর সব ServiceMonitor, PodMonitor আর rule ধরে (selector `{}`), শুধু chart-এর নিজেরগুলো নয়।
  - `exemplar-storage` চালু (6.4-এর exemplar)। Retention ১ দিন, কারণ session কয়েক ঘণ্টার।
  - Grafana:
    - admin-এর password cluster-এর Secret `grafana-admin`-এ;
    - ALB-র `/grafana` path-এ (`serve_from_sub_path`), Traefik-এর `web` entrypoint-এ, host ছাড়া, ArgoCD-র `/argocd`-এর মতো;
    - তার নিজের metrics-ও তাই `/grafana/metrics`-এ।
  - প্রতিটা অংশে requests আর limits।
- **chart (`helm/shoplite`):**
  - `templates/servicemonitor.yaml`: catalog-api (port `http`) আর order-worker (port `metrics`)-এর ServiceMonitor। `/metrics` পড়ে প্রতি ১৫ সেকেন্ডে।
  - order-worker-এর নতুন Service (port 8001), শুধু ServiceMonitor-এর জন্য। আর কেউ worker-এ connect করে না।
- **`scripts/bootstrap-cluster.sh`:** namespace `monitoring` আর Secret `grafana-admin` বানায় (user admin, random password)।
  - Secret আগে থেকে থাকলে রেখে দেয়, কারণ Grafana প্রথম চালুর password-ই রাখে।
  - শেষে Grafana-র ঠিকানা আর password পড়ার command দেখায়।
- **রিহার্সাল:**
  - GitOps (`scripts/tests/bootstrap-cluster.sh`):
    - ArgoCD নিজে kube-prometheus-stack বসায়; তার image আগে থেকে k3s-এ load করা থাকে।
    - test-এর k3s-এ `/`-কে shared mount করা হয় (section 12)।
    - নতুন check-গুলো নিচে যাচাইয়ে।
  - chart (`helm/tests/run.sh`): gitops-এ pin করা chart থেকে ServiceMonitor-এর CRD বসিয়ে নেয়। তারপর দেখে দুই release-এই দুটো ServiceMonitor আছে।
- **Q5-এর পদ্ধতি:** bootstrap-এর তালিকায় Grafana-র Secret যোগ হয়েছে। dev ওঠে kube-prometheus-stack Healthy হওয়ার পরে, তাই অপেক্ষা এখন ৫–৮ মিনিট।

**যাচাই:**
- ✅ chart-এর `helm lint --strict` দুই values-এ। kube-prometheus-stack আমাদের values দিয়ে render হয়:
  - Grafana-র Ingress host ছাড়া, `/grafana`-এ;
  - Prometheus-এ `exemplar-storage` আর সব selector `{}`।
- ✅ kubeconform v0.8.0 `-strict`: নতুন Application valid। shellcheck-এ কোনো আপত্তি নেই।
- ✅ **GitOps রিহার্সাল** `PASS`, অফিসের PC-তে ৯ মিনিটে (প্রথমবার image নামাতে ১২ মিনিট)। ArgoCD নিজে সব বসিয়েছে:
  - kube-prometheus-stack Synced Healthy।
  - ShopLite-এর Application তৈরি হয়েছে ServiceMonitor-এর CRD-এর (05:56:48Z) পরে, 05:56:53Z-এ।
  - Prometheus-এর ১৩টা job-এর সব target `up`, একটাও down নেই। তাদের মধ্যে:
    - node-exporter;
    - kube-state-metrics;
    - catalog-api (দুই env-এ ২টা করে) আর order-worker (১টা করে);
    - kubelet, apiserver, coredns।
  - prod-এর ছয়টা metric Prometheus-এ।
  - latency histogram-এ trace_id-সহ exemplar (যেমন `34ae1079…`)।
  - Grafana `/grafana/`-এ:
    - login ছাড়া API 401;
    - cluster-এর password দিয়ে admin login;
    - data source uid `prometheus` দিয়ে query।
  - আগের সব check আবার pass: bootstrap দুইবার (তিনটা Secret অপরিবর্তিত), `/argocd`, prod-এর manual sync, দুই env-এ order `COMPLETED`, dev-এর self-heal।
- 🐞 প্রথম রানে Grafana-র নিজের target down ছিল (`/metrics` 404)। Grafana sub path-এ চলে বলে তার metrics `/grafana/metrics`-এ। path ঠিক করার পরে সব `up`।
- ✅ Pipeline-এর রিহার্সাল `PASS` (chart-এ ServiceMonitor যোগের পরেও dev আর prod-এর image ঠিক)।
- ✅ **chart-এর রিহার্সাল** (`helm/tests/run.sh`) `PASS`, সাড়ে ৩ মিনিটে, image cache-এ থাকায়:
  - pin করা chart থেকে ServiceMonitor-এর CRD বসেছে;
  - নতুন ServiceMonitor সহ prod-এর সব manifest server-side dry run-এ গৃহীত;
  - দুই release-এ catalog-api আর order-worker-এর ServiceMonitor;
  - আগের সব check আবার pass।
- ⏳ Lab-এ: আসল EC2 node-এ node-exporter, ALB দিয়ে Grafana।

**Step 6.2-এ কী হলো** (`289ea11`)
- **shoplite-gitops-এ তিনটা নতুন Application** (`apps/loki.yaml`, `apps/tempo.yaml`, `apps/alloy.yaml`), kube-prometheus-stack-এর মতোই:
  - namespace `monitoring`;
  - দুই source: chart, আর shoplite-app থেকে values (`ref: app`);
  - sync wave 0। ফলে ShopLite (wave 1) ওঠার আগেই log আর trace নেওয়ার জায়গা তৈরি থাকে।
- **`monitoring/stack/loki.yaml`:** Loki একটা process-এ (monolithic), একটা replica।
  - একটাই tenant (`auth_enabled: false`), replication 1।
  - Storage pod-এর নিজের disk-এ (filesystem, chart-এর 10Gi PVC), object store নেই।
  - Schema v13, tsdb।
  - বন্ধ: gateway (nginx), memcached cache, canary, Helm test, rule-এর sidecar।
  - Simple scalable mode-এর target-গুলোর (write, read, backend) replica 0। chart-এর default 3, আর monolithic-এর সাথে থাকলে chart render-ই করে না।
- **`monitoring/stack/alloy.yaml`:** Alloy, প্রতি node-এ একটা pod (DaemonSet)।
  - প্রতিটা pod নিজের node-এর pod-গুলো খোঁজে, আর তাদের log পড়ে Kubernetes API দিয়ে (`loki.source.kubernetes`)। Node-এর disk পড়ে না, তাই host-এর কোনো folder mount হয় না, আর চলে image-এর নিজের non-root user-এ (uid 473)।
  - প্রতিটা stream-এর label: namespace, pod, container। এর সাথে Alloy নিজে দেয় `job` আর `instance`, আর Loki দেয় `service_name` (section 12)।
  - JSON line থেকে `level` আর `service` label হয়। `trace_id` label হয় না, line-এই থাকে: প্রতি request-এ আলাদা মান, label হলে প্রতি request-এ একটা নতুন stream হতো।
  - যে line JSON নয় (Postgres, Redis, Traefik ইত্যাদি), সেটা যেমন আছে তেমনই যায়।
  - RBAC শুধু `pods` (get, list, watch) আর `pods/log` (get)। chart-এর default সব Secret আর ConfigMap-ও পড়তে পারত।
  - PodLogs CRD বসে না (ব্যবহার হয় না)।
- **`monitoring/stack/tempo.yaml`:** Tempo একটা process-এ, শুধু requests আর limits।
  - Trace থাকে pod-এর disk-এ, chart-এর default ২৪ ঘণ্টা, Prometheus-এর data-র মতো।
  - Receiver chart-এরই, তার মধ্যে OTLP/HTTP 4318। Jaeger-এর receiver সরানো যায় না, কারণ chart-এর Service template সেগুলো ধরে নেয় (section 12)।
- **Grafana-র data source** (`monitoring/stack/kube-prometheus-stack.yaml`)। uid নির্দিষ্ট: `prometheus`, `loki`, `tempo`। নতুন cluster-এও link ঠিক থাকে।
  - **Loki → Tempo:** derived field `trace_id`। regex `"trace_id": *"([0-9a-f]{32})"` line থেকে id নেয়, link খোলে Tempo-তে।
  - **Tempo → Loki:** `tracesToLogsV2`। span-এর `service.name` মিলে যায় Loki-র `service` label-এর সাথে, আর line-এ থাকতে হয় trace-এর id (`filterByTraceID`)। সময় span-এর আগে-পরে ১ মিনিট।
  - **Prometheus → Tempo:** exemplar-এর `trace_id` link খোলে Tempo-তে।
  - Provisioning ফাইলে `${...}` Grafana environment variable হিসেবে পড়ে। তাই URL লেখা `$${__value.raw}`।
- **chart (`helm/shoplite/values.yaml`):** `config.otlpEndpoint` এখন `http://tempo.monitoring.svc.cluster.local:4318`। দুই env-ই এখানে পাঠায়; trace-এ `deployment.environment` থেকে বোঝা যায় কোনটা dev, কোনটা prod।
- **রিহার্সাল (`scripts/tests/bootstrap-cluster.sh`):** loki, tempo, alloy-এর image আগে থেকে load হয় (`stack_images`, chart আর values Application থেকে পড়ে)। নতুন check-গুলো নিচে যাচাইয়ে।
- **Q5-এর পদ্ধতি:** bootstrap-এর অপেক্ষার তালিকায় loki, tempo, alloy; অপেক্ষা এখন ৫–১০ মিনিট।

**যাচাই:**
- ✅ তিনটা chart আমাদের values দিয়ে render হয়:
  - Loki: একটা StatefulSet (10Gi PVC, non-root), config-এ filesystem আর `auth_enabled: false`;
  - Tempo: একটা StatefulSet;
  - Alloy: DaemonSet, ClusterRole-এ শুধু `pods` আর `pods/log`।
- ✅ Alloy-র pipeline `grafana/alloy:v1.21.3`-এর `alloy fmt` আর GA stability-তে `alloy run`-এ গৃহীত। শুধু in-cluster config না পেয়ে থামে, যা cluster-এর বাইরে প্রত্যাশিত।
- ✅ kubeconform `-strict`: ৮টা Application valid। shellcheck-এ আপত্তি নেই। chart-এর `helm lint --strict` দুই values-এ।
- ✅ **GitOps রিহার্সাল** `PASS`, অফিসের PC-তে ১৩ মিনিটে। ArgoCD নিজে সব বসিয়েছে, তারপর:
  - loki, tempo, alloy Synced Healthy। ShopLite-এর Application (wave 1) তৈরি হয়েছে 11:12:30Z-এ, ServiceMonitor-এর CRD-এর (11:11:04Z) পরে।
  - Loki-তে ছয়টা namespace-এর log: argocd, kube-system, monitoring, shoplite, shoplite-dev, traefik।
  - Label-এ `level` আর `service` আছে (মান web, catalog-api, order-worker); `trace_id` label নয়।
  - prod-এর order 1-এর line পাওয়া গেছে LogQL দিয়ে: `| json | message="order created" | order_id="1"`।
  - Grafana-র Loki data source-এর নিজের regex সেই line থেকে trace_id বের করে, আর link যায় uid `tempo`-তে।
  - Tempo-তে সেই trace-এ ৭টা span:
    - catalog-api: `POST /orders` (SERVER), `INSERT orders` (CLIENT), `send orders:pending` (PRODUCER);
    - order-worker: `process orders:pending` (CONSUMER), `simulate work`, আর দুটো `UPDATE orders` (CLIENT)।

    worker-এর span API-র queue span-এর child, আর `deployment.environment` prod।
  - Tempo data source-এর link (uid `loki`, `service.name` → `service`, trace-এর id দিয়ে) worker-এর ২টা line পায়: `order processing started`, `order completed`।
  - Prometheus data source-এর exemplar link যায় `tempo`-তে, আর exemplar-এর trace Tempo-তে আছে।
  - আগের সব check আবার pass।
- 🐞 প্রথম রানে `service=web` log পাওয়া যায়নি। web শুধু আসল request-এর log লেখে (`/healthz` বাদ), আর রিহার্সালের order যায় `/api`-তে, যা Traefik সরাসরি catalog-api-তে পাঠায়। এখন রিহার্সাল আগে দুই env-এর page একবার খোলে।
- ✅ রিহার্সালের cluster রেখে দিয়ে দেখা হয়েছে: Alloy প্রতিটা container একবারই পড়ে (section 12)।
- ✅ Pipeline-এর রিহার্সাল `PASS`।
- ✅ **chart-এর রিহার্সাল** (`helm/tests/run.sh`) `PASS`, নতুন OTLP ঠিকানা নিয়ে। সেখানে Tempo নেই, তবু ২৯টা check-ই pass। এবার লেগেছে ২০ মিনিট (আগে ৪–১০)। কোন ধাপে সময় গেছে, log-এ সময় না থাকায় বলা যায় না।
- ⏳ Lab-এ: তিনটা আসল node-এ Alloy, আর Grafana-র UI-তে link-গুলোতে click (6.5-এর পদ্ধতিতে)।

**Step 6.3-এ কী হলো** (`cadd840`)
- **`monitoring/dashboards/golden-signals.json`:** dashboard "ShopLite — Golden Signals" (uid `shoplite-golden-signals`)। উপরে Environment বাছাই: `shoplite` (prod, default) বা `shoplite-dev`। প্রতি ১০ সেকেন্ডে নিজে refresh হয়।
  - প্রশ্নের ৭টা জিনিস, ৮টা panel-এ:
    - Requests per second, route অনুযায়ী;
    - HTTP 5xx error rate, route অনুযায়ী। কোনো error না থাকলেও ০ দেখায় (`or ... * 0`), ফাঁকা নয়;
    - Worker replicas: available, আর HPA কতগুলো চায়;
    - Request latency per route: p50, p95, p99। p99-এর query-তে exemplar চালু, তাই graph-এ বিন্দু আসে আর click করলে trace খোলে (6.2-এর link);
    - Order queue depth (catalog-api-এর gauge, দুই replica-র `max`);
    - Orders created vs processed (processed, result অনুযায়ী);
    - CPU usage per pod আর Memory usage per pod (kubelet-এর cAdvisor থেকে, `metrics_path="/metrics/cadvisor"`)।
  - Alert-এর সীমা লাল রেখা হিসেবে দেখায়: 5xx-এ 5%, latency-তে 1 s, queue-তে 50। ফলে 6.4-এর alert আর dashboard একই সংখ্যা দেখায়।
  - Q8-এর জন্য বাড়তি ৩টা (user-এর সিদ্ধান্ত, 16 Nov; PLAN অনুযায়ী), আলাদা "Investigation" অংশে:
    - **Restarted containers:** কোন container কতবার restart হয়েছে, আর শেষবার কেন বন্ধ হয়েছে (যেমন `OOMKilled`)। কিছু restart না হলে ফাঁকা।
    - **Recent error logs:** Loki থেকে environment-এর `level="ERROR"` line। Line খুললে trace_id-এর link।
    - **Deploy-এর দাগ:** panel নয়, dashboard-এর annotation। কোনো Deployment বদলালে (`kube_deployment_metadata_generation`) সব graph-এ বেগুনি দাগ পড়ে।
  - সব panel data source ধরে uid দিয়ে (`prometheus`, `loki`)।
- **`monitoring/kustomization.yaml`:** dashboard-এর JSON থেকে ConfigMap `shoplite-dashboards` বানায়, namespace `monitoring`-এ, label `grafana_dashboard: "1"`। Grafana-র sidecar এই label দেখে dashboard তোলে।
  - নাম নির্দিষ্ট (hash suffix নেই), তাই Git-এ বদলালে একই ConfigMap বদলায়।
  - Kustomize, Helm নয়: dashboard-এর JSON-এ `{{ }}` (Grafana-র legend) আছে, যা Helm নিজের template ভেবে ভেঙে ফেলত (PLAN)।
- **`shoplite-gitops/apps/monitoring-config.yaml`:** ArgoCD-র Application, shoplite-app-এর `monitoring/` folder Kustomize দিয়ে বসায়। Wave 1, monitoring stack (wave 0)-এর পরে। 6.4-এর alert rule-ও এখানে যোগ হবে।
- **রিহার্সাল (`scripts/tests/bootstrap-cluster.sh`):** monitoring-config Synced Healthy হওয়ার অপেক্ষা, তারপর নতুন check, নিচে যাচাইয়ে।

**যাচাই:**
- ✅ Kustomize v5.8.1 (`kubectl kustomize`, k3s-এর image থেকে) ConfigMap বানায়, label সহ। kubeconform `-strict`: ৯টা Application আর ConfigMap valid। shellcheck-এ আপত্তি নেই।
- ✅ **GitOps রিহার্সাল** `PASS` (অফিসের PC, সাড়ে ১১ মিনিট), dashboard-এর প্রথম সংস্করণে। ArgoCD নিজে monitoring-config বসিয়েছে, তারপর:
  - Grafana-র API-তে uid `shoplite-golden-signals`, নাম হুবহু "ShopLite — Golden Signals", প্রশ্নের ৮টা panel, latency panel-এ exemplar।
  - প্রতিটা panel-এর query, আর deploy-এর দাগের query, prod-এর জন্য Grafana-র data source দিয়ে সফল।
  - প্রশ্নের ৮টা panel-এ data আছে। যেমন CPU আর memory-তে ৭টা pod, orders processed-এ ৪টা result।
  - আগের সব check আবার pass।
- 🐞 সেই cluster রেখে দিয়ে আসল ঘটনা ঘটিয়ে দেখা হয়েছিল। তাতে ধরা পড়ে: restart-এর table-এ `reason` আসে না, কারণ `on (pod, container)` বাকি label বাদ দেয়। `group_left` যোগ করা হয়েছে (section 12)।
- ✅ একই cluster-এ হাতে পরখ:
  - `group_left`-সহ query দেখায় order-worker, কারণ `Completed`, restart 1 (dev-এ worker-এর process থামানোর পরে);
  - dev-এ একটা অবৈধ queue message দিলে "Recent error logs"-এর query worker-এর `invalid queue message dropped` line পায়, trace_id সহ;
  - prod-এর web scale করার ১৯ সেকেন্ড পরে deploy-এর দাগ আসে।

  এই তিনটা পরীক্ষা এখন রিহার্সালেও আছে: dashboard-এর ধাপে, আর self-heal ধাপের `kubectl scale`-এর ঠিক পরে।
- ✅ **শেষ সংস্করণে পুরো GitOps রিহার্সাল `PASS`** (17 Nov, অফিসের PC, ১৫.৭ মিনিট), 6.4-এর সাথে একই রানে। তিনটা নতুন check-ও pass:
  - dev-এ "Recent error logs"-এ worker-এর ERROR line;
  - "Restarted containers"-এ order-worker, `Completed`, restart 1;
  - self-heal-এর `kubectl scale`-এর পরে prod-এর web-এ deploy-এর দাগ।

  16 Nov সন্ধ্যার রানটা PC বন্ধ হওয়ায় metrics-এর ধাপে কেটে গিয়েছিল (কোনো FAIL নেই)।
- 🐞 17 Nov সকালের প্রথম রান একবার থেমেছিল Grafana-র ধাপে: data source uid `prometheus`-এর proxy query সফল হয়নি। আগের রানগুলোতে এই check pass করেছিল, আর এর পরের রানেও pass করেছে। সেবার কারণ ধরার মতো তথ্য ছিল না। এখন এই check ব্যর্থ হলে Grafana-র উত্তর আর `monitoring`-এর pod-গুলো দেখায়। রানের শেষে রিহার্সাল এখন restart হওয়া সব container-এর তালিকাও দেখায়; পরের রানে সেখানে ছিল শুধু dev-এর সেই order-worker, যেটা রিহার্সাল নিজে থামায়।
- ⏳ Lab-এ: load চলা অবস্থায় dashboard (live demo-র checkpoint), আর UI-তে exemplar ও log থেকে trace-এ click।

**Step 6.4-এ কী হলো** (`9e65283`)
- **`monitoring/alert-rules/shoplite-alerts.yaml`:** প্রশ্নের ৫টা alert, একটা PrometheusRule-এ (group `shoplite`)। প্রতিটায় `severity` label, আর `runbook_url`, যা এই repo-র runbook-এর link (`https://github.com/SaikatGeek/shoplite-app/blob/main/monitoring/runbooks/<alert>.md`)।

  | Alert | শর্ত | Severity |
  |---|---|---|
  | HighErrorRate | route অনুযায়ী 5xx-এর ভাগ 5%-এর বেশি, ৫ মিনিট | critical |
  | HighLatency | route অনুযায়ী p95 ১ সেকেন্ডের বেশি, ৫ মিনিট | warning |
  | QueueBacklog | `max(order_queue_depth)` ৫০-এর বেশি, ১০ মিনিট | warning |
  | PodCrashLooping | ১০ মিনিটে কোনো container-এর restart বেড়েছে (প্রথম restart-এই বাজে) | critical |
  | NodeDiskFilling | node-এর `/` ৮৫%-এর বেশি ভরা, ৫ মিনিট | warning |

  দুই env-ই দেখা হয়; `namespace` label বলে কোনটা। summary আর description-এ route, namespace আর মান থাকে, তাই Slack-এর message নিজেই বলে কী হয়েছে।
- **`monitoring/runbooks/`:** ৫টা runbook, প্রতিটা alert-এর নামে। প্রতিটায় আছে:
  - লক্ষণ আর প্রভাব;
  - প্রথম ৫ মিনিটে dashboard-এর কোন panel আর Explore-এর কোন query (PromQL, LogQL, TraceQL);
  - সম্ভাব্য কারণ আর সমাধান (বদল এলে Git-এ revert, তারপর ArgoCD sync);
  - কখন ঠিক হলো বলা যাবে।

  কোনো runbook-এ chaos flag-এর নাম নেই, যাতে Q8 শুধু observability দিয়েই সমাধান করতে হয়।
- **`monitoring/alert-rules/tests/`:** promtool-এর unit test (`shoplite-alerts.test.yaml`), আর `run.sh`, যা চালায়:
  - ৫টা alert-এর নাম আর severity প্রশ্নের table-এর সাথে মেলায়;
  - প্রতিটা `runbook_url` আর তার runbook ফাইল আছে কি না দেখে;
  - `promtool check rules` আর `promtool test rules` চালায়: প্রতিটা alert শুধু তার সময় পার হলে বাজে, label আর annotation সহ, আর পাশের সুস্থ series চুপ থাকে।
- **`monitoring/kustomization.yaml`:** PrometheusRule যোগ হয়েছে। ArgoCD-র `monitoring-config` dashboard-এর সাথে এটাও বসায়।
- **Alertmanager → Slack** (`monitoring/stack/kube-prometheus-stack.yaml`):
  - সব alert যায় Slack-এর receiver-এ, `alertname` আর `namespace` ধরে group হয়ে; resolve হলেও message যায়;
  - message-এ title `[FIRING] <alert> (<severity>) in <namespace>`, তারপর summary, description আর runbook-এর link;
  - chart-এর পুরনো route আর inhibit rule সরানো (সেগুলো chart-এর default alert-এর জন্য, যা বসানো হয় না)।
- **Webhook-এর URL Git-এ নেই।** Alertmanager পড়ে ফাইল থেকে (`api_url_file`), Secret `alertmanager-slack` (key `webhook-url`) mount করে।
  - Secret বানায় `scripts/bootstrap-cluster.sh`, `SLACK_WEBHOOK_URL` থেকে।
  - প্রথমবার এটা না দিলে script কিছু বদলানোর আগেই থামে।
  - পরের রানে না দিলে আগের Secret রাখে; দিলে হালনাগাদ করে।
  - URL কখনো screen-এ আসে না।
- **Q5-এর পদ্ধতি:** নতুন 0.3 (Slack-এ incoming webhook বানানো একবার), আর bootstrap-এর আগে `read -rsp` দিয়ে URL নেওয়া, যাতে screen বা shell-এর history-তে না থাকে।
- **রিহার্সাল (`scripts/tests/bootstrap-cluster.sh`):** একটা নকল Slack webhook (python-এর ছোট server, fixed IP 172.30.0.11), আর নতুন check, নিচে যাচাইয়ে।

**যাচাই:**
- ✅ `bash monitoring/alert-rules/tests/run.sh` `PASS`:
  - ৫টা নাম আর severity প্রশ্নের table-এর সাথে মেলে, আর ৫টা runbook আছে;
  - `promtool check rules`: ৫টা rule;
  - `promtool test rules`: SUCCESS।
- ✅ Mutation: ৯টা ইচ্ছাকৃত ভুল, প্রতিটায় test FAIL:
  - HighErrorRate-এর সীমা 0.05 → 0.2;
  - `for: 5m` → `1m`;
  - p95 → p50;
  - latency-র সীমা 1 → 3;
  - queue-র `max` → `sum`;
  - `for: 10m` → `5m`;
  - restart-এর window 10m → 30m;
  - disk-এর সীমা 0.85 → 0.95;
  - critical → warning।
- ✅ Chart থেকে render করা Alertmanager-এর config `amtool check-config` (v0.34.2)-এ SUCCESS। তাতে আছে শুধু slack receiver, URL-এর বদলে ফাইলের path। chart-এর পুরনো route আর inhibit rule নেই।
- ✅ Kustomize বানায় ConfigMap আর PrometheusRule, দুটোই kubeconform-এ valid।
- ✅ **GitOps রিহার্সাল** `PASS`, 6.3-এর সাথে একই রানে:
  - bootstrap দুবার। Slack-এর Secret আসে `SLACK_WEBHOOK_URL` থেকে, দ্বিতীয়বার অপরিবর্তিত থাকে, আর URL কোথাও print হয় না।
  - Prometheus ৫টা alert evaluate করে, severity আর runbook_url সহ।
  - Alertmanager-এর config-এ শুধু ফাইলের path আছে, URL নেই।
  - dev-এর order-worker restart-এর পরে নকল Slack webhook পেয়েছে `[FIRING] PodCrashLooping (critical) in shoplite-dev`, runbook-এর link সহ।
- ✅ রানের পরে cluster রেখে আরও পরখ:
  - message-এর title-এর link বদলে runbook-এ দেওয়া হয়েছে, কারণ default link যায় Alertmanager-এর ভেতরের ঠিকানায়। বদলটা পরীক্ষার Git server-এ push করার পরে ArgoCD ৯০ সেকেন্ডে sync করেছে।
  - prod-এর worker restart-এর ৮৪ সেকেন্ড পরে Slack-এ নতুন message এসেছে, title-এর link runbook-এ।
  - Runbook-এর ১৩টা query (PromQL, LogQL, TraceQL) Grafana-র data source দিয়ে চালানো হয়েছে, সবগুলো valid (HTTP 200)।
- ⏳ Lab-এ: আসল Slack channel-এ message।

**Step 6.5-এ কী হলো** (`4f4002e`)
- **`docs/evidence/q6/commands.md`** (English, grader-এর জন্য): lab-এ Q6-এর প্রমাণ নেওয়ার পদ্ধতি। Q5-এর পদ্ধতির section 4 পর্যন্ত করার পরে, একই session-এ।
  - 0: k6 install, checksum মিলিয়ে।
  - 1: Grafana-র ঠিকানা আর password।
  - 2–3 (6a, 6b): stack, data source, `up` আর ছয়টা metric, ServiceMonitor।
  - 4–5 (6c): k6 দিয়ে prod-এ ২২ RPS, তারপর load চলা অবস্থায় dashboard, আর তার ConfigMap।
  - 6 (6d): এক order-এর log → trace → log, আর exemplar → trace।
  - 7 (6e): ৫টা alert rule, আর dev-এর worker একবার থামিয়ে Slack-এ পরীক্ষামূলক alert।
  - 8: ভিডিও V3। dev-এ GitHub-এর web editor দিয়ে error-এর fault চালু, HighErrorRate বাজে, তারপর Slack → runbook → dashboard → error log → trace, ২ মিনিটের মধ্যে। শেষে আবার Git দিয়ে ঠিক করা।
  - ১৭টা screenshot আর একটা ভিডিও।
- **`scripts/loadtest.js`** (k6 v1.8.2, PLAN-এর বাছাই): দুটো constant-arrival-rate scenario।
  - catalog ১৬/s (অর্ধেক তালিকা, অর্ধেক একটা product);
  - order ৬/s, চারটা worker-এর ক্ষমতার প্রায় ৬০% (PLAN)।

  হার নির্দিষ্ট থাকে, ShopLite ধীর হলেও। `BASE_URL` লাগবেই; `DURATION` (default 15m, Q8-এর শর্ত), `BROWSE_RPS`, `ORDER_RPS` বদলানো যায়।

**যাচাই:**
- ✅ k6-এর install block হুবহু একটা নতুন `ubuntu:24.04`-এ: checksum `OK`, `k6 v1.8.2`।
- ✅ রিহার্সালের cluster রেখে, পদ্ধতির section 1, 2, 3 আর 5-এর bash block হুবহু, একটা নকল lab machine থেকে (bash, kubectl): Grafana-র password, Application, pod, ServiceMonitor, dashboard-এর ConfigMap আর তার label।
- ✅ পদ্ধতির query-গুলো সেই cluster-এ Grafana দিয়ে:
  - `count by (job, namespace) (up == 1)`: ১৩টা সারি;
  - `up == 0`: ফাঁকা;
  - ছয়টা metric: ৬টা সারি;
  - LogQL-এ prod-এর `order created` line।
- ✅ k6 এক মিনিট prod-এ (k6-এর Docker image, node-এর network থেকে NodePort 30080): ২২.৭ request/s, ১৩২২টা check-এর সবগুলো pass, কোনো request ব্যর্থ নয়, p95 ৪.৬ ms।
- dev-এর values-এ ওই তিনটা লাইন দিলে chart-এর render-এ `CHAOS_ERROR_RATE: "0.2"` হয়, আর checksum বদলায় বলে pod roll করে।
- ✅ **V3-এর পথ, রিহার্সালের cluster-এ:**
  - পরীক্ষার Git server-এ dev-এর values-এ তিনটা লাইন commit করার পরে ArgoCD dev-এর ConfigMap বদলেছে ১২০ সেকেন্ডে, আর catalog-api roll করেছে।
  - তারপর k6 dev-এ চলেছে (NodePort 30081)।
  - HighErrorRate pending হয়েছে 10:46:22-এ, আর নকল Slack-এ পৌঁছেছে 10:51:56-এ: `[FIRING] HighErrorRate (critical) in shoplite-dev`, "18.86% of the requests to /orders in shoplite-dev failed with a 5xx status", title-এর link runbook-এ।
  - dev-এর ERROR line (`request completed`, `POST /orders`, status 500) থেকে trace_id। Tempo-তে সেই trace-এ শুধু একটা span: `POST /orders` (SERVER), status ERROR, পেছনে কোনো DB বা queue span নেই। পদ্ধতি এটাই দেখতে বলে।
  - তারপর Git-এ revert। নকল Slack-এ `[RESOLVED] HighErrorRate` এসেছে ৫৪৪ সেকেন্ড পরে; পদ্ধতিতে তাই "প্রায় ১০ মিনিট" লেখা।
  - dev-এ k6: ২২.৫ request/s। order-এর ১৭% ব্যর্থ (fault ২০%, কিছু সময় বন্ধ ছিল)। catalog-এর ১৭টা (০.২%) ব্যর্থ হয়েছে, fault চালু আর বন্ধের সময় catalog-api-এর pod roll হওয়ার ফাঁকে।

## 7. Q7: CI/CD আর GitOps

**Repo-র ব্যবস্থা (user-এর সিদ্ধান্ত, 14 Nov):** কাজের সুবিধার জন্য `shoplite-app` আর `shoplite-gitops` এখন `devops-final`-এর দুটো folder। শেষে দুটো আলাদা GitHub repo-তে push হবে (`SaikatGeek/shoplite-app`, যেখানে এখন শুধু একটা `test.md`, আর `SaikatGeek/shoplite-gitops`, যা এখনো নেই)।
- Code লেখা হয় শেষের repo-র URL ধরে।
- GitHub Actions আর ArgoCD আসল repo ছাড়া চলে না। তাই **যে lab session-এ ArgoCD আর pipeline চলবে (Q5 থেকে), তার আগেই ভাগ করতে হবে।** Q3 আর Q4-এর lab ভাগ ছাড়াই চলে।
- ভাগ করার সময় `shoplite-app`-এর `test.md` আমাদের code দিয়ে বদলে যাবে। User অনুমতি দিয়েছে (15 Nov): force push হবে, `git subtree split`-এর history সহ।

**GitOps-এর ভিত আগে** (user-এর সিদ্ধান্ত, 14 Nov: PLAN-এর পথ)। PLAN Phase 6 অনুযায়ী Q7-এর এই অংশ Q5-এর lab-এর আগে লাগে। Cluster প্রতি session-এ নতুন হয়, তাই প্রথম দিন থেকেই সব Git থেকে ArgoCD দিয়ে বসে, আর image ECR-এ যায় pipeline দিয়ে।

| Step | কাজ | প্রশ্নের অংশ | অবস্থা |
|---|---|---|---|
| 7.1 | shoplite-gitops-এর কাঠামো: root app, dev আর prod-এর Application, `envs` values | (c) | ✅ `b3b00a0` |
| 7.2 | Cluster-এর bootstrap: namespace, DB-র Secret, pin করা ArgoCD, root app; ArgoCD ALB-র `/argocd`-এ; local রিহার্সাল (ArgoCD Git থেকে sync করে) | (c), (d) | ✅ `7adece6` |
| 7.3 | Terraform-এ GitHub OIDC: CI-এর IAM role, শুধু তিনটা ECR repo-তে push | (a) | ✅ `ac8e1b3` |
| 7.4 | Pipeline-এর প্রথম সংস্করণ: build → OIDC দিয়ে ECR-এ push → gitops-এ tag commit | (a) | ✅ `e23bf34`, "Run workflow" বোতাম `2e538cc` (GitHub-এ প্রথম run repo ভাগের পরে) |
| 7.5 | prod-এ তোলার workflow (`promote.yml`): dev-এর image prod-এর values-এ commit, তারপর ArgoCD-তে হাতে sync | (c) | ✅ `7d4076a` (user-এর সিদ্ধান্ত: 5.4-এর আগে) |
| 7.6 | main pipeline-এ lint (Hadolint, `helm lint`), test আর Trivy-র gate, `scripts/ci.sh`-এর ধাপ হিসেবে | (a) | ✅ `ea44401` (GitHub-এ চালানো বাকি) |
| 7.7 | PR pipeline (`pr.yml`): lint, test, build, scan; `terraform/` বদলালে plan PR-এ comment (`terraform-plan.yml`, read-only plan role) | (b) | ✅ `aa4083d` (GitHub-এ চালানো বাকি) |
| 7.8 | Lab-এর পদ্ধতি `docs/evidence/q7/commands.md`: pipeline, PR, Trivy-র লাল run, ArgoCD, self-heal, checkpoint | সব | ✅ `6d8bd3c` (lab-এ চালানো বাকি) |

**Step 7.1-এ কী হলো** (`shoplite-gitops/`, `b3b00a0`)
- **`bootstrap/root-app.yaml`:** root Application ("app of apps")। Cluster বানানোর সময় শুধু এটা একবার হাতে বসানো হবে; এরপর `apps/`-এর সব Application ArgoCD নিজেই Git থেকে বানায় আর বদলায়।
- **`apps/shoplite-dev.yaml`:** namespace `shoplite-dev`। Automated sync, `prune` (Git থেকে সরানো জিনিস cluster থেকেও মোছে) আর `selfHeal` (হাতে বদলালে Git-এর অবস্থায় ফেরায়, Q7d)।
- **`apps/shoplite-prod.yaml`:** namespace `shoplite`, **manual sync**; বদল OutOfSync হয়ে অপেক্ষা করে, যতক্ষণ না কেউ sync চায়। ArgoCD-র self-heal শুধু automated sync-এর সাথে চলে, তাই self-heal দেখানো হবে dev-এ (PLAN; README-র deviation log-এ যাবে)।
- **Values তিন স্তরে** (ArgoCD multi-source, পরেরটা আগেরটাকে ছাপিয়ে যায়):
  1. chart-এর `values.yaml`;
  2. shoplite-app-এর `values-<env>.yaml`;
  3. shoplite-gitops-এর `envs/<env>/values.yaml`।
- **`envs/dev/values.yaml`:** image-এর registry আর tag; CI প্রতি push-এ লিখবে। এখন ফাঁকা, তাই chart থামে `image.tag is required`-এ, image ছাড়া pod চালু করে না।
- **`envs/prod/values.yaml`:** prod-এ তোলা image, আর Q8-এর চারটা chaos flag (সব বন্ধ)। Peer এখানেই একটা চালু করবে।
- **Sync-এর ক্রম:** Traefik wave 0, ShopLite wave 1, কারণ chart-এর Middleware-এর জন্য Traefik-এর CRD আগে লাগে। সাথে retry: কিছু তখনো না থাকলে sync আবার চেষ্টা করে।
- **README:** কাঠামো আর values-এর স্তর লেখা।

**যাচাই** (ArgoCD ছাড়া যতটুকু; ArgoCD-সহ পুরো পরীক্ষা 7.2-এর রিহার্সালে):
- Application-গুলো যে ক্রমে values দেয়, সেই ক্রমে `helm template`:
  - যেমন commit করা (ফাঁকা): থামে `image.tag is required`-এ।
  - CI-এর মতো tag লিখলে image হয় `<ECR>/shoplite/<service>:<tag>`।
  - dev বসে `dev` entrypoint-এ, prod বসে `web`-এ।
  - Prod-এ একটা chaos flag চালু করলে ConfigMap-এর checksum বদলায়, তাই sync-এ pod নতুন হয়।
- kubeconform v0.8.0 `-strict` দিয়ে চারটা Application (root, traefik, dev, prod) ArgoCD-র Application CRD-এর schema-য় বৈধ। ইচ্ছা করে একটা field-এর বানান ভুল করলে বাতিল করে।

**Step 7.2-এ কী হলো** (`7adece6`)
- **`shoplite-app/scripts/bootstrap-cluster.sh`:** নতুন cluster-এ একবার চলে, lab-এর machine থেকে। `kubectl` আর `helm` লাগে; kubeconfig চলে SSM tunnel দিয়ে; shoplite-gitops পাশে থাকতে হবে (নইলে `SHOPLITE_GITOPS_DIR`)। ক্রমে:
  1. namespace `shoplite` (prod) আর `shoplite-dev`;
  2. প্রতিটায় Secret `shoplite-db` (`POSTGRES_USER=shoplite`, random password)। Secret আগে থাকলে রেখে দেয়, কারণ Postgres প্রথম চালুর password-ই রাখে; তাই আবার চালানো নিরাপদ।
  3. ArgoCD, তার নিজের Helm chart থেকে, pin করা (chart 10.11.6 = ArgoCD v3.5.6), values shoplite-gitops থেকে;
  4. root app। এরপর বাকি সব ArgoCD Git থেকে বসায়।

  কোনো secret Git-এ বা screen-এ যায় না। Admin-এর password থাকে cluster-এর Secret `argocd-initial-admin-secret`-এ; কীভাবে পড়তে হয়, script শেষে বলে দেয়।
- **`shoplite-gitops/bootstrap/argocd-values.yaml`:** ArgoCD-র setting (PLAN অনুযায়ী):
  - ALB-র `/argocd` path-এ, Traefik-এর `web` entrypoint দিয়ে (port 80)। Host-এর নিয়ম নেই, কারণ ALB-র DNS নাম প্রতি session-এ বদলায়। Domain নেই বলে certificate নেই, তাই ArgoCD চলে plain HTTP-তে (`server.insecure`); login ছাড়া কিছু দেখা যায় না।
  - Git দেখে প্রতি 60 সেকেন্ডে।
  - Application-এর health check (ArgoCD-র docs-এর Lua): root app Traefik (wave 0) Healthy হওয়া পর্যন্ত অপেক্ষা করে, তারপর ShopLite (wave 1)।
  - Ingress-এর health check: রিহার্সালে পাওয়া সমস্যার সমাধান (নিচে)।
  - Dex (SSO) আর notifications বন্ধ; প্রতিটা অংশে requests আর limits।
- **রিহার্সাল `shoplite-app/scripts/tests/bootstrap-cluster.sh`**, সাথে তিনটা ফাইল:
  - `gitserver.Dockerfile` আর `gitserver-nginx.conf`: test-এর Git server (nginx + `git http-backend`), যা দুই folder-কে দুটো repo হিসেবে HTTP-তে দেখায়, GitHub-এর মতো।
  - `tools.Dockerfile`: lab-এর machine-এ যা লাগে (bash, kubectl, helm)।

  Test-এর gitops copy-তে শুধু GitHub-এর URL test server-এর দিকে ঘোরানো হয়, আর `envs`-এ image tag `local` লেখা হয়, CI যেমন লিখবে।

**যাচাই:** রিহার্সাল `bash scripts/tests/bootstrap-cluster.sh` অফিসের PC-তে (15 Nov) প্রথম চেষ্টাতেই `PASS`, ৫ মিনিট ৩৭ সেকেন্ডে (বাসার PC-তে প্রায় ১৫ মিনিট লাগে)। কোনো কিছু হাতে বসানো হয়নি; সব ArgoCD Git থেকে বসিয়েছে।
- ✅ Test-এর Git server-এ দুই repo, server-এর container-এর ভেতরে তৈরি; k3s-এর network থেকে পৌঁছায়।
- ✅ `bootstrap-cluster.sh`: namespace, দুই Secret, ArgoCD-র সব pod, root app। দ্বিতীয়বার চালালে দুই Secret অপরিবর্তিত থাকে।
- ✅ কেউ sync না করেই traefik, তারপর shoplite-dev Synced Healthy; root Synced Healthy। Ingress-এর health check values ফাইল থেকেই কাজ করে (বাসার PC-তে তখন চলমান cluster-এ হাতে বসাতে হয়েছিল)।
- ✅ Sync wave সত্যিই অপেক্ষা করে: Traefik-এর Middleware CRD তৈরি 07:11:05Z, Traefik available 07:11:16Z, আর ঠিক তখনই dev আর prod-এর Application তৈরি।
- ✅ prod OutOfSync Missing, namespace `shoplite`-এ কিছু বসেনি; তবু root-এর sync শেষ হয়। শেষ wave-এর health-এর জন্য root অপেক্ষা করে না।
- ✅ ALB-র port 80-র NodePort (30080)-এ `/argocd/`: ArgoCD-র page (`<base href="/argocd/">`), login ছাড়া API 401, cluster-এর password দিয়ে admin login; Git দেখে প্রতি 60 সেকেন্ডে।
- ✅ ArgoCD-র API দিয়ে prod-এর manual sync (UI-এর Sync বোতাম যা পাঠায়): prod Synced Healthy, তারপর root Synced Healthy।
- ✅ ArgoCD-র বসানো দুই environment order নেয়: dev (NodePort 30081, ALB 8080) আর prod (30080, ALB 80), দুটোতেই `COMPLETED`।
- ✅ Self-heal (Q7d): dev-এ `kubectl scale` দিয়ে web 2 থেকে 4 করলে ArgoCD আবার 2 করে (Git-এর মান)। prod-এ একই বদল থেকে যায় (4), আর app OutOfSync দেখায়, যতক্ষণ না কেউ sync করে।
- 🐞 রিহার্সালে (বাসার PC-তে) পাওয়া তিনটা সমস্যা আর তাদের সমাধান:
  1. **Ingress-এর health।** ArgoCD Ingress-কে Healthy বলে শুধু তখন, যখন controller তাতে load balancer-এর ঠিকানা লেখে। Traefik NodePort-এর পেছনে আর ALB Terraform-এর, তাই ঠিকানা কখনো আসে না। ফলে dev, prod আর root চিরকাল "Progressing" থাকত, lab-এও। সমাধান: `argocd-values.yaml`-এ Ingress-এর health check। চলমান cluster-এ একই Lua বসিয়ে দেখা হয়েছে: dev আর root সাথে সাথে Synced Healthy।
  2. **রিহার্সালের repo %TEMP%-এ ছিল।** বাসার PC-তে 02:05:10-এ কিছু একটা %TEMP%-এর সব খালি folder মুছে দেয়, তার মধ্যে bare repo-র `refs/`-ও। তখন ArgoCD পায় `repository not found`। সমাধান: repo এখন Git server-এর container-এর ভেতরে তৈরি হয়।
  3. **`/argocd` page-এর পরীক্ষা ভুল ছিল।** ArgoCD `<base href="/argocd/">` লেখে শুধু browser-এর request-এ (`Accept: text/html`)। curl পেয়েছিল আসল ফাইল (`<base href="/">`), তাই পরীক্ষা ভুল করে fail করেছিল। সমাধান: পরীক্ষা এখন `Accept: text/html` পাঠায়।

  আর wave-এর পরীক্ষা এখন Middleware CRD তৈরির সময়ের সাথে মেলায়, Traefik-এর pod-এর সাথে নয় (কারণ section 12-এ)।

**Step 7.3-এ কী হলো** (`ac8e1b3`): GitHub Actions কোনো AWS key ছাড়াই ECR-এ push করবে।
- **`terraform/modules/github-oidc/`:**
  - `main.tf`:
    - **OIDC identity provider** (`token.actions.githubusercontent.com`, audience `sts.amazonaws.com`): AWS GitHub-এর দেওয়া token বিশ্বাস করে। প্রতিটা workflow run GitHub থেকে একটা স্বল্পমেয়াদি token পায়, আর AWS সেটা বদলে দেয় এক ঘণ্টার credential-এ।
    - **Role `shoplite-github-ci`:** নিতে পারে শুধু `SaikatGeek/shoplite-app`-এর `main` branch-এর run। `StringEquals` দিয়ে হুবহু মেলায়, wildcard নেই; তাই PR, অন্য branch বা অন্য repo পারে না।
    - **Policy `ecr-push`:** ECR-এ login (`GetAuthorizationToken`; AWS এটা repo দিয়ে সীমিত করতে দেয় না) আর AWS-এর docs-এ push-এর যে ছয়টা action আছে, শুধু তিনটা repo-র ARN-এ। Delete বা অন্য কিছু নেই।
  - `variables.tf`: input যাচাই করে। repo হতে হবে `owner/name`, আর ARN হতে হবে ECR repo-র ARN, wildcard ছাড়া। ভুলে `*` দিলে push সব repo-তে খুলে যেত।
  - `outputs.tf`: `role_arn`, `oidc_provider_arn`।
  - `tests/github_oidc.tftest.hcl`: ৮টা run (নিচে)।
- **Root:** `main.tf`-এ `module "github_oidc"`, ECR module-এর ARN দিয়ে। `outputs.tf`-এ `ci_role_arn`, যা workflow-কে `role-to-assume` হিসেবে দিতে হবে (7.4)। Q4-এর একই `apply`-এ তৈরি হয়।
- **Q4-এর lab পদ্ধতি** (`docs/evidence/q4/commands.md`): দুটো fallback যোগ হলো।
  - Account OIDC provider বানাতে না দিলে: instructor-কে জানাও, আর Q4 চালিয়ে যেতে module-টা comment out করো।
  - GitHub-এর provider আগে থেকেই থাকলে (`EntityAlreadyExists`): `terraform import` করো, আর শেষের destroy-এর আগে `state rm`, যাতে provider-টা থেকে যায়।

**যাচাই** (AWS ছাড়া, `hashicorp/terraform:1.17.2`-এ):
- ✅ `fmt -check`, root-এর `validate`; module-এর ৮টা test আর root-এর ১০টা pass।
- ✅ Test যে সত্যিই ভুল ধরে, তা দেখা হয়েছে container-এর ভেতরে code ইচ্ছা করে ভুল করে (host-এর ফাইল অপরিবর্তিত)। নিচের ৮টা ভুলের প্রত্যেকটায় test fail করেছে:
  - যেকোনো branch (`*`);
  - `pull_request`;
  - `StringLike`;
  - audience-এর শর্ত বাদ;
  - `BatchDeleteImage` যোগ;
  - push সব repo-তে (`*`);
  - login-এর জায়গায় `ecr:*`;
  - root-এ ARN-এর বদলে repo-র URL পাঠানো।
- ✅ AWS-এর docs-এর push permission-এর তালিকার সাথে মেলানো (ECR User Guide, "IAM permissions for pushing an image")।
- ✅ Fallback-এর command:
  - `import` address মেনে নেয়, থামে credential-এ। ভুল address দিলে বলে "does not exist in the configuration"।
  - `state rm` একটা নমুনা state থেকে provider-টা সরায়।

**Step 7.4-এ কী হলো** (`e23bf34`): main-branch pipeline-এর প্রথম সংস্করণ। Repo ভাগের পরে GitHub-এ চলবে (GitHub শুধু repo-র গোড়ার `.github/workflows` চালায়)।
- **`shoplite-app/.github/workflows/main.yml`:** main-এ প্রতিটা push-এ একটা job:
  1. checkout, tag = short commit SHA (`${GITHUB_SHA::7}`);
  2. তিনটা image build (`--target runtime`);
  3. `LAB_ACTIVE` `true` হলে:
     - OIDC দিয়ে CI-এর role নেয় (`AWS_ROLE_ARN`, `AWS_REGION`; না দিলে region `ap-southeast-1`);
     - ECR-এ login আর push (`<registry>/shoplite/<service>:<sha>`);
     - deploy key (`GITOPS_DEPLOY_KEY`) দিয়ে shoplite-gitops checkout করে `update-gitops.sh` চালায়।
  4. `LAB_ACTIVE` না থাকলে শুধু build হয়, আর একটা notice দেখায়। এতে lab-এর বাইরের push-এও run সবুজ থাকে (PLAN)।

  অন্য বিষয়গুলো:
  - Action-গুলো commit SHA দিয়ে pin করা (PLAN): checkout v7.0.1, configure-aws-credentials v6.3.0, amazon-ecr-login v2.1.7। প্রতিটাই তখন দুই সপ্তাহের বেশি পুরনো সর্বশেষ release।
  - `concurrency`: একবারে একটা run, push-এর ক্রমে, যাতে দেরিতে শেষ হওয়া পুরনো run নতুন tag-এর ওপর লিখতে না পারে।
  - Permission শুধু `contents: read` আর `id-token: write`। `kubectl` বা cluster-এর কোনো credential নেই।
  - Actions tab-এ "Run workflow" বোতাম (`workflow_dispatch`, `2e538cc`, user-এর সিদ্ধান্ত)। Lab session-এর শুরুতে ECR খালি থাকে; বোতাম main-এর সর্বশেষ commit-এর image push করে, নতুন commit লাগে না। অন্য branch থেকে চালালে AWS-এ পৌঁছায় না, কারণ CI-এর role শুধু main-কে মানে।
- **`shoplite-app/scripts/update-gitops.sh`:** shoplite-gitops-এর checkout-এ `envs/<env>/values.yaml`-এ registry আর tag লেখে।
  - Commit করে `github-actions[bot]` হিসেবে, message-এ run-এর link আর source commit।
  - তারপর push করে। প্রতিবার শুরু করে সর্বশেষ main থেকে, তাই মাঝে অন্য কারো commit এলে সেটা থাকে। তিনবার চেষ্টা করে।
  - একই tag আবার দিলে কিছু commit করে না।
  - Input যাচাই করে: environment `dev`/`prod`, registry শুধু host, tag Docker-এর নিয়মে।
  - পরের `promote` workflow-ও (prod) এটাই ব্যবহার করবে।
- **রিহার্সাল `shoplite-app/scripts/tests/pipeline.sh`** (সাথে `runner.Dockerfile`: GitHub runner-এর মতো bash, git, yq), প্রায় ২০ সেকেন্ড:
  1. actionlint দিয়ে workflow, `run:`-এর ভেতরে shellcheck; shellcheck দিয়ে script-গুলো। Workflow-এর trigger ঠিক দুটো: main-এ push আর `workflow_dispatch`।
  2. প্রতিটা action:
     - comment-এ লেখা release-এর commit-এ pin করা কিনা (GitHub থেকে tag এনে মেলায়);
     - যে input দেওয়া হচ্ছে, সেই commit-এর `action.yml`-এ আছে কিনা, আর দরকারি input দেওয়া কিনা;
     - workflow যে output পড়ে, সেটা আছে কিনা।

     actionlint নতুন release চেনে না: `aws-regoin` বানান ভুল সে ধরেনি, এই পরীক্ষা ধরে।
  3. `update-gitops.sh`, shoplite-gitops-এর একটা bare copy-র বিরুদ্ধে ("GitHub"):
     - প্রথম run-এ একটাই commit, শুধু dev-এর ফাইল, comment থাকে;
     - একই tag-এ কিছু হয় না;
     - checkout-এর পরে অন্য কেউ prod-এ chaos flag আর dev-এ quote ছাড়া tag push করলে, আর প্রথম push বাতিল হলে: সর্বশেষ main থেকে আবার চেষ্টা করে, অন্যের commit থাকে;
     - `0123456` আর `1e23456` string থাকে;
     - ভুল input বাতিল হয়।
  4. CI-এর লেখা values দিয়ে chart (dev Application-এর মতো স্তরে) ECR-এর image দেখায়।

**যাচাই:**
- ✅ রিহার্সাল `PASS`, container রেখে যায় না।
- ✅ Mutation: copy-তে ৯টা ইচ্ছাকৃত ভুলের প্রত্যেকটায় রিহার্সাল fail করেছে:
  - ভুল SHA;
  - comment-এর version SHA-র সাথে মেলে না;
  - input-এর বানান ভুল;
  - নেই এমন output;
  - সর্বশেষ main না আনা;
  - কিছু না বদলালেও commit;
  - প্রথম বাতিলেই হাল ছাড়া;
  - `env()` (YAML-কে type ঠিক করতে দেওয়া);
  - dev-এর tag prod-এর ফাইলে লেখা।
- ✅ বোতাম যোগের পরে (`2e538cc`) রিহার্সাল আবার `PASS` (১৬ সেকেন্ড)। Trigger-এর আরও ৪টা ভুলের প্রত্যেকটায় fail করেছে: বোতাম মুছে ফেলা, সব branch-এর push-এ চালানো, আরেকটা branch যোগ, pull request-এও চালানো।
- ✅ GitHub-এর ubuntu-24.04 runner-এ yq 4.54.3, git আর docker আছে (runner-images-এর তালিকা)।
- ⏳ GitHub-এ আসল run: repo ভাগের পরে, lab session-এ (deploy key, variable, `LAB_ACTIVE`)। সেটাই Q7a-এর প্রমাণ।

**Step 7.5-এ কী হলো** (`7d4076a`; user-এর সিদ্ধান্ত, 15 Nov: 5.4-এর আগে, কারণ Q5-এর checkpoint prod-এ চলে, আর prod-এর values তখনো ফাঁকা)
- **`shoplite-app/.github/workflows/promote.yml`:** শুধু Actions tab-এর "Run workflow" বোতাম থেকে চলে।
  1. shoplite-app আর deploy key দিয়ে shoplite-gitops checkout করে।
  2. shoplite-gitops-এর `envs/dev/values.yaml` থেকে dev যে image চালায় তার registry আর tag পড়ে।
  3. `update-gitops.sh` দিয়ে সেটা `envs/prod/values.yaml`-এ commit আর push করে।
  4. শেষে notice দেয়: ArgoCD-তে shoplite-prod sync করো (prod manual sync)।

  অন্য বিষয়গুলো:
  - AWS বা cluster লাগে না: dev image চালায় মানে সেটা ECR-এ আছে। তাই `LAB_ACTIVE`, OIDC বা `id-token` নেই; permission শুধু `contents: read`।
  - Input নেই: যা dev-এ চলছে, শুধু সেটাই prod-এ যায়।
  - prod-এর chaos flag (Q8) ছোঁয় না, শুধু image-এর দুই লাইন।
  - dev-এ তখনো image না থাকলে error দিয়ে থামে ("run the main workflow first"), কিছু commit করে না।
- **`update-gitops.sh`:** prod-এর commit-এর message এখন "Promoted from dev by <run-এর link>"। dev-এর আগের মতোই "Built and pushed by <run> from <repo>@<sha>"।
- **রিহার্সাল `pipeline.sh`** এখন দুই workflow-ই দেখে:
  - trigger (promote শুধু বোতামে);
  - প্রতিটা workflow-এর pin, input আর output;
  - promote-এর নিজের step, GitHub-এর মতো workspace-এ (shoplite-app-এর ভেতরে shoplite-gitops);
  - লেখা values দিয়ে chart dev আর prod দুটোতেই।

**যাচাই:**
- ✅ রিহার্সাল `PASS` (২০ সেকেন্ড):
  - promote একটা commit দেয় `github-actions[bot]` হিসেবে, message-এ run-এর link।
  - বদলায় শুধু `envs/prod/values.yaml`। prod পায় dev-এর registry আর tag (`1e23456`, string থাকে)।
  - আগের case-এর prod chaos flag (`slowDb: true`) থেকে যায়।
  - dev-এ image না থাকলে থামে, commit নেই।
  - prod-এর values দিয়ে chart namespace `shoplite`-এ ECR-এর তিনটা image দেখায়।
- ✅ Mutation: নতুন অংশে ৬টা ইচ্ছাকৃত ভুলের প্রত্যেকটায় fail করেছে:
  - prod-এর commit-এ "built and pushed";
  - dev-এর বদলে prod-এর values পড়া;
  - ফাঁকা dev-এর check বাদ;
  - prod-এর বদলে dev-এ লেখা;
  - push-এও চালানো;
  - checkout tag দিয়ে pin।

  আগের workflow-এর ভুলগুলোও (ভুল SHA, ভুল version-এর comment, input-এর বানান, নেই এমন output, বোতাম মোছা, সব branch) নতুন loop-এ আবার fail করেছে।
- ⏳ GitHub-এ আসল run: repo ভাগের পরে, lab session-এ।

**Step 7.6-এ কী হলো** (`ea44401`)
- **`scripts/ci.sh`:** দুই pipeline-এর check, এক একটা ধাপ এক একবার ডাকলে। GitHub Actions আর যেকোনো Docker-ওয়ালা machine ঠিক একই command চালায়।
  - `lint`: তিনটা Dockerfile-এ Hadolint, আর chart-এর `helm lint --strict`, dev আর prod-এর values দিয়ে।
  - `test`: তিন service-এর unit test (তাদের Docker test stage চালিয়ে), আর alert-এর promtool test।
  - `build <tag>`: তিনটা runtime image, `shoplite/<service>:<tag>`।
  - `scan <tag>`: তিনটা image-এ Trivy। কোনোটায় CRITICAL থাকলে fail, তবে আগে তিনটাই scan করে, যাতে এক রানেই সব দেখা যায়।

  সব tool চলে digest দিয়ে pin করা image থেকে: Hadolint v2.15.1, Helm 4.3.1, Trivy v0.76.1 (দুই সপ্তাহের বেশি পুরনো সর্বশেষ release)। tag সরানো যায়, digest যায় না; PLAN-এর `trivy-action`-এর tag hijack-এর কথা মনে রেখে action-এর বদলে image।
- **`.github/workflows/main.yml`:** build-এর আগে lint আর test, build-এর পরে scan, তারপর আগের মতো OIDC → ECR → gitops। যে image push হয়, scan হয় ঠিক সেটাই, একই job-এ। চারটা check সব সময় চলে, `LAB_ACTIVE` থাকুক বা না থাকুক।
- **Dockerfile:** Hadolint-এর আপত্তি ঠিক করা হয়েছে।
  - তিনটার `HEALTHCHECK` এখন JSON রূপে (DL3025)। busybox-এর wget connection refused আর HTTP 500-এ নিজেই 1 দিয়ে বের হয়, তাই `|| exit 1` লাগে না।
  - web-এর runtime stage-এ `brotli-libs=1.2.1-r0` (version pin করা, DL3018)। base image `nginx-unprivileged:1.30.6-alpine`-এর brotli-libs 1.2.0-r1-এ CRITICAL CVE-2026-111497 আছে, আর nginx-unprivileged-এর কোনো tag-এ এখনো নতুন build নেই (সব 19 Oct-এর)। base image ঠিক হলে লাইন দুটো তুলে দিতে হবে।
  - `USER 0` দিয়ে install, তারপর আবার `USER 101`। সংখ্যায় লেখা, কারণ Hadolint নামে লেখা user চায় না (DL3066)।
- **রিহার্সাল (`scripts/tests/pipeline.sh`):**
  - main-এর lint, test, build আর scan সব সময় চলে, আর AWS-এর যেকোনো ধাপের আগে;
  - `ci.sh`-এর প্রতিটা image digest দিয়ে pin করা, আর সেই digest registry-তে আছে;
  - `ci.sh`-এর চারটা ধাপ এখানে চালানো হয়;
  - web-এর ঠিক না করা base image দিলে scan fail করে, তিনটাই scan করে, আর web-এর নাম বলে।

**যাচাই:**
- ✅ Hadolint-এ তিনটা Dockerfile পরিষ্কার। `helm lint --strict` দুই values-এ।
- ✅ Unit test: web-এর ১৫টা check, catalog-api ৪৮টা, order-worker ২৯টা, আর alert-এর promtool test।
- ✅ Trivy: আগে web-এ ১টা CRITICAL (brotli-libs), fix-এর পরে তিনটা image-ই ০। web চলে uid 101-এ; আকার ৬৫.৭ MB (আগে ৬৪.৬)।
- ✅ আলাদা compose project-এ (`shoplite-ci`, port 8099) নতুন image দিয়ে পাঁচটা service healthy, smoke test `PASS`। user-এর নিজের stack অপরিবর্তিত।
- ✅ Pipeline-এর রিহার্সাল `PASS`, ৫৯ সেকেন্ডে। চারটা ইচ্ছাকৃত ভুলের প্রতিটায় FAIL: scan শুধু `LAB_ACTIVE`-এ, scan push-এর পরে, lint বাদ, Trivy শুধু tag দিয়ে।
- ⏳ GitHub-এ আসল run: repo ভাগের পরে, lab session-এ।

**Step 7.7-এ কী হলো** (`aa4083d`)
- **`.github/workflows/pr.yml`:** main-এ আসা প্রতিটা PR-এ `scripts/ci.sh`-এর চারটা ধাপ: lint, test, build (tag `pr-<number>`), Trivy-র scan।
  - কিছু push হয় না, কোনো AWS বা GitHub secret লাগে না; permission শুধু `contents: read`।
  - একই PR-এ নতুন push এলে পুরনো run বাতিল হয়।
- **`.github/workflows/terraform-plan.yml`:** main-এ আসা যে PR `terraform/` বদলায়, তার plan PR-এ comment হিসেবে।
  - read-only plan role নেয় OIDC দিয়ে (`vars.AWS_PLAN_ROLE_ARN`); push role কখনো নয়।
  - `scripts/terraform-plan.sh` চালায়, তারপর `gh pr comment` দিয়ে post করে (`GITHUB_TOKEN`, `pull-requests: write`)। plan ব্যর্থ হলেও comment যায়, কারণসহ।
  - শুধু `LAB_ACTIVE` থাকলে; নইলে শুধু একটা notice।
  - Setting: variable `AWS_PLAN_ROLE_ARN` আর `SSH_PUBLIC_KEY` (apply-এর একই key), secret `BUDGET_ALERT_EMAIL` (apply-এর একই ঠিকানা; ব্যক্তিগত, তাই secret)।
- **`scripts/terraform-plan.sh`:**
  - account থেকে state bucket বের করে (`shoplite-tfstate-<account>-<region>`);
  - pin করা `hashicorp/terraform:1.17.2`-এ `init`, তারপর `plan -lock=false -input=false`, যাতে state-এ কিছু লেখা না হয়;
  - comment-এ থাকে summary (`Plan: ...` বা `No changes.`) আর পুরো output ভাঁজ করা অবস্থায় (শেষের ৬০,০০০ অক্ষর; GitHub-এর সীমা ৬৫,৫৩৬);
  - init বা plan ব্যর্থ হলে comment লিখে তারপর non-zero দিয়ে বের হয়।
- **Terraform (`modules/github-oidc`):** নতুন role `shoplite-github-plan`। trust শুধু `repo:SaikatGeek/shoplite-app:pull_request` (exact match), policy AWS-এর `ReadOnlyAccess`। output `plan_role_arn`, root-এ `ci_plan_role_arn`। CI role অপরিবর্তিত, শুধু main।
- **রিহার্সাল (`scripts/tests/pipeline.sh`):**
  - দুই PR workflow-এর trigger;
  - `pr.yml`-এ চারটা check, কোনো AWS action নেই, permission শুধু `contents: read`;
  - `terraform-plan.yml`-এ role শুধু `AWS_PLAN_ROLE_ARN`, আর ঠিক এই তিনটা permission;
  - কোনো PR workflow-এ `AWS_ROLE_ARN` বা `GITOPS_DEPLOY_KEY` নেই;
  - plan চলে `-lock=false`-এ;
  - AWS ছাড়া plan script comment লেখে আর fail করে।

**যাচাই:**
- ✅ `terraform fmt -check`, `validate`; module-এর ১০টা আর root-এর ১০টা test pass।
- ✅ IAM-এর mutation: ছয়টা ইচ্ছাকৃত ভুল, প্রতিটায় test FAIL:
  - plan role-এ wildcard;
  - plan role-কে main trust করা;
  - CI role-কে PR trust করা;
  - `AdministratorAccess`;
  - push policy plan role-এ;
  - নাম বদলানো।
- ✅ actionlint আর shellcheck পরিষ্কার।
- ✅ Pipeline-এর রিহার্সাল `PASS`, ৭০ সেকেন্ডে। পাঁচটা ইচ্ছাকৃত ভুলের প্রতিটায় FAIL:
  - plan-এ CI role;
  - `pr.yml`-এ `id-token`;
  - `pr.yml` থেকে scan বাদ;
  - plan-এ lock;
  - `pr.yml` সব branch-এ।
- ⏳ Lab-এ: GitHub-এ দুটো PR (একটা সাধারণ, একটা `terraform/` বদলে) আর plan-এর comment।

**Step 7.8-এ কী হলো** (`6d8bd3c`)
- **`docs/evidence/q7/commands.md`** (English, grader-এর জন্য): lab-এ Q7-এর প্রমাণ, Q5-এর পদ্ধতির section 4-এর পরে, একই session-এ।
  - 0: PR-এর plan-এর setting। secret `BUDGET_ALERT_EMAIL` একবার। variable `SSH_PUBLIC_KEY` আর `AWS_PLAN_ROLE_ARN` প্রতি session-এ, কারণ lab machine আর তার key নতুন।
  - 1 (7a): সবুজ main run, তার ধাপের ক্রম; ECR-এর tag আর main-এর short SHA মেলানো; shoplite-gitops-এ CI-র commit।
  - 2 (7a): Trivy-র লাল run। একটা PR, যাতে web-এর Dockerfile থেকে brotli-র fix সরানো; `pr` check fail করে CVE-2026-111497 দিয়ে। PR merge হয় না।
  - 3 (7b): একটা সাধারণ PR আর সবুজ check। একটা `terraform/` বদলের PR (budget 20 → 25): `pr` আর `terraform-plan` দুটোই চলে, আর comment-এ "Plan: 0 to add, 1 to change, 0 to destroy."।
  - 4 (7c): দুই Application-এর sync policy, terminal আর ArgoCD-তে।
  - 5 (7d): `kubectl edit` দিয়ে dev-এর web-এর replicas বদলানো; ArgoCD ফিরিয়ে আনে। ভিডিও V5।
  - 6: checkpoint। title বদলে devops-final থেকে split আর push, তারপর pipeline → gitops → ArgoCD → browser, কোনো deploy command ছাড়া। ভিডিও V4।
  - ১১টা screenshot আর দুটো ভিডিও।
- **PR-গুলো কখনো merge হয় না** (Claude-এর বাছাই)। GitHub-এর web editor-এ নতুন branch-এ বানানো, পরে বন্ধ করা। shoplite-app-এর main এগোয় শুধু devops-final থেকে আবার split-এ; merge হলে split-এর fast-forward ভেঙে যেত।

**যাচাই:**
- ✅ Section 4-এর kubectl block হুবহু একটা ছোট k3s-এ (`rancher/k3s:v1.37.2-k3s1`, ArgoCD chart 10.11.6-এর Application CRD, shoplite-gitops-এর dev আর prod Application): dev-এ `map[prune:true selfHeal:true]`, prod-এ `<none>`।
- ✅ Section 5-এর `kubectl edit`, nano-র বদলে একটা sed editor দিয়ে: replicas 2 → 5। ArgoCD-র ফিরিয়ে আনা GitOps রিহার্সালে প্রতিবার যাচাই হয়।
- ✅ Section 1-এর `aws ecr describe-images` credential ছাড়া চালানো হয়েছে: শুধু "Unable to locate credentials"-এ থামে, মানে argument ঠিক। তার `--query` jmespath 1.0.1-এ API-র আকারের নমুনায় tag-গুলো দেয়।
- Split-এর command Q5-এর পদ্ধতির section 0.1-এর, যা আগেই যাচাই করা।

**দুই repo ভাগ (17 Nov)**
- **user-এর নিয়ম (17 Nov):** নতুন দুই repo-তে কোথাও Claude-এর নাম যাবে না। devops-final-এর পুরনো commit-এ থাকলে সমস্যা নেই। তাই:
  - এখন থেকে কোনো commit-এ `Co-Authored-By: Claude` লাইন নেই;
  - split-এর history থেকে সেই লাইন আর root-এর notes ফাইলের নাম মোছা হয়।
- **`publish-repos.sh`** (devops-final-এর root):
  - দুই ফোল্ডার `git subtree split` করে `split/<folder>` branch-এ;
  - `git filter-branch --msg-filter` দিয়ে message পরিষ্কার করে। author, committer আর তারিখ অপরিবর্তিত থাকে, তাই প্রতিবার ঠিক একই commit হয়;
  - পরিষ্কারের পরে যাচাই করে কোনো message-এ আর নাম রইল কি না;
  - `push` দিলে শুধু shoplite-app push করে, fast-forward হিসেবে।

  root-এ নতুন `.gitattributes` (`*.sh text eol=lf`), যাতে Windows-এ script CRLF না হয়।
- **Publish:**
  - shoplite-app-এ `--force-with-lease=main:cd15953`। আগে পরখ করা হয়েছিল যে GitHub-এর `main`-এ শুধু placeholder `test.md`-এর একটা commit আছে; শুধু সেটাই বদলেছে।
  - shoplite-gitops খালি ছিল, তাই সাধারণ push।
  - shoplite-app ৩৮টা commit (`a4a5267`), shoplite-gitops ৯টা (`53ada93`)। GitHub-এর `main` local branch-এর সাথে হুবহু মেলে।
  - সব commit-এর author আর committer user ("Md. Ariful Islam Saikat" বা "SaikatGeek")। GitHub-এর commits page-এ প্রতিটা "SaikatGeek committed", কোনো co-author নেই।
  - Script দুবার চালিয়ে একই hash পাওয়া গেছে, তাই পরের publish fast-forward হবে।
- **প্রথম আসল CI run (main #1) লাল:** Unit tests-এ `promtool: error: stat shoplite-alerts.rules.yaml: permission denied`।
  - alert test-এর `mktemp -d` ফোল্ডার 0700, আর Prometheus-এর image চলে `nobody` হিসেবে।
  - Windows-এর Docker Desktop mount-এর permission মানে না, তাই local-এ pass করত।
  - WSL Ubuntu-তে একই ভুল ঘটানো গেছে। `chmod -R a+rX` দিয়ে ঠিক করার পরে WSL-এ `ci.sh`-এর চারটা ধাপই pass করেছে (section 12)।
- shoplite-gitops এখন থেকে বদলাবে তার নিজের clone-এ বা GitHub-এর web editor-এ, কারণ CI সেখানে commit করে। devops-final-এর `shoplite-gitops/` আর source নয়।

## 7b. Q8: Chaos Day আর RCA

| Step | কী | অবস্থা | Commit |
|---|---|---|---|
| 8.1 | Lab-এর পদ্ধতি, RCA-র কাঠামো, architecture diagram `docs/`-এ | ✅ | `a641940` |
| 8.2 | Lab-এ exercise (screenshot, timeline, ভিডিও V6) | ⬜ | |
| 8.3 | RCA লেখা, তারপর peer-এর commit-এর সাথে মেলানো (দুইটা আলাদা commit) | ⬜ | |

**8.1-এ কী হলো (17 Nov):**

- **`docs/evidence/q8/commands.md`** (English), প্রশ্নের ৮.১-এর ধাপ ধরে:
  - নিয়ম: RCA লেখা পর্যন্ত Git-এর diff, ArgoCD-র APP DIFF, pod-এর env বা ConfigMap দেখা যাবে না; তদন্ত শুধু Grafana দিয়ে (Prometheus, Loki, Tempo), সাথে Slack-এর alert আর runbook। kubectl নয়।
  - Timeline: `mark` function প্রতিটা ধাপের সময় `~/q8-timeline.txt`-এ লেখে, UTC+6-এ (Grafana-র dashboard browser-এর সময় দেখায়, Slack আর PC-র ঘড়িও তাই)।
  - ধাপ: peer-কে collaborator করা → k6 একটানা (২২ RPS, `DURATION=60m`), ৫ মিনিট পরে সুস্থ dashboard → peer-এর commit → diff না দেখে ArgoCD-তে prod sync → peer-এর access সরানো → তদন্ত (alert, runbook, dashboard, log, trace, root cause-এর এক লাইন) → নিজের PC থেকে `git revert` আর push → আবার sync → dashboard-এ recovery আর Slack-এ RESOLVED → cluster থাকতে থাকতে RCA-র ৭টা সংখ্যা (PromQL) → RCA লেখা, তারপর diff।
  - শেষে "The peer's part": invitation নেওয়া, `envs/prod/values.yaml`-এ ঠিক একটা লাইন বদলানো (`latencyMs: 1500`, `errorRate: 0.2`, `memoryLeak: true` বা `slowDb: true`), নিরীহ message, শুধু "done" বলা।
- **`docs/RCA.md`:** কাঠামো, TODO সহ: summary, timeline (প্রতিটা ঘটনার পাশে screenshot), detection, investigation (dashboard → logs → trace), root cause, recovery time (detect, identify, recover, মোট), impact, একটা preventive measure, আর শেষে "RCA লেখার পরে change-এর সাথে মেলানো"।
- **Architecture diagram** root থেকে `shoplite-app/docs/`-এ (`git mv`, প্রশ্নের ২.১-এর `docs/architecture-diagram`): `architecture-diagram.md` (লেখা এখন English, ছবি একই) আর তিনটা PNG। PNG তিনটা এখনকার stack-এর সাথে মিলিয়ে দেখা হয়েছে।

**যাচাই:**

- ✅ পদ্ধতির ১৮টা bash block markdown থেকে হুবহু তুলে চালানো:
  - timeline-এর ১৩টা `mark` আর `cat` নতুন `ubuntu:24.04`-এ (tzdata ছাড়া): প্রতিটা লাইন `+06`, ঘণ্টা `date -u` + ৬;
  - section 6 আর 9-এর git block shoplite-gitops-এর একটা bare stand-in-এর বিরুদ্ধে, peer-এর commit-এর পরে CI-র একটা dev commit সহ: revert শুধু peer-এর commit-টা উল্টায়, prod-এর values আগের মতো, dev-এরটা অক্ষত, revert-এর output-এ diff নেই, section 9-এর `git show` peer-এর বদলটা দেখায়।
- ✅ Section 8-এর ৭টা PromQL promtool-এর `promql_expr_test` দিয়ে নমুনা series-এ (Prometheus v3.15.1): প্রতিটা প্রত্যাশিত সংখ্যা দেয় (5xx ৩২৪০, route-প্রতি request, order ১২৯৬০, p95 ২.০৫ s আর ০.৪৭৫ s, queue ৫০, restart ৩), dev-এর series বাদ পড়ে।
- ✅ shoplite-app আর shoplite-gitops-এর কোনো ফাইলে Claude বা Anthropic-এর নাম নেই; commit-এ trailer নেই। `bash publish-repos.sh push`: `6ba1eed..88ae898`, fast-forward, ৪১টা commit।

## 7c. shoplite-app-এর README (PLAN-এর Phase 10)

`04b7063` (18 Nov), `shoplite-app/README.md`, English, grader-এর জন্য:

- কী আছে: application আর API-র table, চারটা fault-injection setting (Compose-এ `.env`, Kubernetes-এ gitops-এর `config.chaos`), local-এ চালানো (`make up && make smoke`, `make test`), repo-র layout, AWS-এ কীভাবে চলে (Terraform → Ansible → bootstrap → ArgoCD → GitHub Actions), workflow-এর GitHub setting (৫টা variable, ২টা secret), secret কোথায় থাকে, test আর রিহার্সালের table, প্রশ্ন ধরে প্রমাণের index, আর deviation log (১৬টা: domain নেই, self-heal dev-এ, Ingress-এর health check, k3s-এর containerd, node-এর UFW, ECR-এর credential provider, Q3-এর আলাদা VPC, `LAB_ACTIVE` আর "Run workflow", promote, Compose-এ trace backend নেই, stock কমে না, dashboard-এর Investigation অংশ, alert-এর ব্যাখ্যা, brotli-র pin, Q8-এর এক ঘণ্টার load, এক-command-এর script নেই)।

**যাচাই:**

- ✅ GitHub থেকে নতুন clone (`88ae898`), Git Bash-এ Makefile-এর command হাতে (Windows-এ `make` নেই), আলাদা project name আর port-এ: পাঁচটা component healthy, smoke `PASS: order 1 COMPLETED`, unit test (web সব check, API ৪৮, worker ২৯), page 200। পরে test-এর volume আর clone মোছা।
- ✅ README-র Terraform loop হুবহু: `fmt -check` আর আটটা folder-এর `terraform test` (১০, ৩, ৭, ৭, ৯, ৮, ৪, ১০ test), সব pass।
- ✅ চারটা doc-এর ৩২টা relative link আর README-র `#tests` anchor মেলে; কোনো ফাইলে Claude বা Anthropic-এর নাম নেই।
- WSL-এর check চলেনি: তখন Docker Desktop নতুন করে চালু হচ্ছিল (WSL বলেছিল `docker could not be found`)। চালু হওয়ার পরে Git Bash-এ চালানো হয়েছে।

## 8. Commit-এর তালিকা

| Commit | তারিখ | কী |
|---|---|---|
| `04ad552` | 2026-11-12 | Data services আর catalog-api core (Step 1, 2) |
| `fd89722` | 2026-11-12 | Orders API (Step 3) |
| `3ede8c1` | 2026-11-12 | order-worker (Step 4) |
| `225269e` | 2026-11-12 | ৬টা metric (Step 5) |
| `2a33e9c` | 2026-11-12 | Tracing (Step 6) |
| `161c225` | 2026-11-12 | ৪টা chaos flag (Step 7) |
| `eb46deb` | 2026-11-12 | web: page, Nginx, Dockerfile (Step 9) |
| `6c68826` | 2026-11-12 | Q2: compose-এ পাঁচটা component, smoke test, Makefile, pip ছাড়া image |
| `3019a9a` | 2026-11-12 | Q3: `linux/` folder (sshd_config, backup service আর timer, UFW, commands) |
| `d690cb5` | 2026-11-12 | Q4 step 4.1: state bucket, S3 backend lock সহ, tag, budget |
| `6733b56` | 2026-11-12 | Q4 step 4.2: network module (দুই AZ-এ VPC, subnet, IGW, NAT) |
| `bd07fcf` | 2026-11-12 | Q4 step 4.3: compute module (security group, SSM-এর role, ৩টা node) |
| `2d9d0fc` | 2026-11-12 | Q4 step 4.4: alb module (ALB, listener 80 আর 8080, target group, security group) |
| `9e1c75e` | 2026-11-12 | Q4 step 4.5: ecr module (তিনটা image repo) |
| `5a0b220` | 2026-11-12 | Q4 step 4.6: q3-server (Q3-এর EC2, নিজের ছোট VPC-তে) |
| `4f4a286` | 2026-11-12 | Q4 step 4.7a: Ansible-এর ভিত আর hardening role |
| `f862f1d` | 2026-11-13 | Q4 step 4.7b: k3s-এর role (container runtime, server, agent, kubeconfig) |
| `d85bb48` | 2026-11-14 | Q4 step 4.7c: node-এ SSH key, lab-এর inventory আর kubectl-এর tunnel (Terraform output) |
| `135b8ea` | 2026-11-14 | Q4 step 4.7c: ECR থেকে image টানতে kubelet-এর credential provider |
| `5cc1286` | 2026-11-14 | Q4 step 4.8: lab-এ Q4 চালানোর পদ্ধতি আর প্রমাণের তালিকা |
| `9fa4aeb` | 2026-11-14 | Q5 step 5.1: Helm chart-এ পাঁচটা workload, Secret আর ConfigMap, local রিহার্সাল |
| `14e4bd0` | 2026-11-14 | Q5 step 5.2: PDB, HPA, Ingress; Traefik-এর ArgoCD Application (shoplite-gitops) |
| `f367f76` | 2026-11-14 | Q5 step 5.3: Postgres আর Redis-এর NetworkPolicy |
| `b3b00a0` | 2026-11-14 | Q7 step 7.1: shoplite-gitops-এর root app, dev আর prod-এর Application, `envs` values |
| `7adece6` | 2026-11-15 | Q7 step 7.2: bootstrap script, ArgoCD-র values, GitOps-এর রিহার্সাল |
| `ac8e1b3` | 2026-11-15 | Q7 step 7.3: GitHub OIDC-এর role, শুধু তিনটা ECR repo-তে push (Terraform) |
| `e23bf34` | 2026-11-15 | Q7 step 7.4: main pipeline v1 (build, OIDC দিয়ে ECR, gitops-এ tag), `update-gitops.sh`, pipeline-এর রিহার্সাল |
| `2e538cc` | 2026-11-15 | Q7 step 7.4: pipeline-এ "Run workflow" বোতাম (`workflow_dispatch`), রিহার্সালে trigger-এর check |
| `7d4076a` | 2026-11-15 | Q7 step 7.5: `promote` workflow (dev-এর image Git দিয়ে prod-এ), রিহার্সালে দুই workflow |
| `04305e8` | 2026-11-15 | Q5 step 5.4: lab-এ Q5 চালানোর পদ্ধতি (repo ভাগ, GitHub-এর setting, pipeline, bootstrap, promote, প্রমাণ) |
| `cb6830f` | 2026-11-16 | Q6 step 6.1: metrics stack (kube-prometheus-stack ArgoCD দিয়ে), ServiceMonitor, exemplar, Grafana `/grafana`-এ |
| `289ea11` | 2026-11-16 | Q6 step 6.2: Loki, Alloy (JSON parse), Tempo (OTLP) ArgoCD দিয়ে; Grafana-য় log → trace, trace → log, exemplar → trace |
| `cadd840` | 2026-11-16 | Q6 step 6.3: "ShopLite — Golden Signals" dashboard (Kustomize, monitoring-config), Q8-এর restart, error log আর deploy-এর দাগ সহ |
| `9e65283` | 2026-11-17 | Q6 step 6.4: ৫টা alert (PrometheusRule), ৫টা runbook, promtool-এর test, Alertmanager → Slack (URL শুধু cluster-এর Secret-এ) |
| `4f4002e` | 2026-11-17 | Q6 step 6.5: lab-এ Q6-এর পদ্ধতি (`docs/evidence/q6/commands.md`, ভিডিও V3 সহ), k6-এর load test `scripts/loadtest.js` |
| `ea44401` | 2026-11-17 | Q7 step 7.6: main pipeline-এ lint (Hadolint, helm lint), test, Trivy-র gate (`scripts/ci.sh`); Dockerfile-এ Hadolint-এর fix, web-এ brotli-libs-এর CRITICAL-এর fix |
| `aa4083d` | 2026-11-17 | Q7 step 7.7: PR pipeline (`pr.yml`), PR-এ Terraform plan-এর comment (`terraform-plan.yml`, `scripts/terraform-plan.sh`), read-only plan role (Terraform) |
| `6d8bd3c` | 2026-11-17 | Q7 step 7.8: lab-এ Q7-এর পদ্ধতি (`docs/evidence/q7/commands.md`: pipeline, Trivy-র লাল run, PR আর plan-এর comment, ArgoCD, self-heal, checkpoint) |
| `2ec91d8`, `7d312a8`, `82e12f0` | 2026-11-17 | `publish-repos.sh` (split, message থেকে Claude-এর নাম মোছা, শুধু shoplite-app push) আর root-এর `.gitattributes`; দুই repo GitHub-এ publish |
| `41db62e` | 2026-11-17 | fix: alert test-এর ফোল্ডার promtool পড়তে পারে (GitHub-এর প্রথম run-এর ভুল, Linux-এ permission) |
| `c12bdd0` | 2026-11-17 | Q5 আর Q7-এর পদ্ধতিতে `publish-repos.sh` |
| `a641940` | 2026-11-17 | Q8 step 8.1: lab-এর পদ্ধতি (`docs/evidence/q8/commands.md`), RCA-র কাঠামো (`docs/RCA.md`), architecture diagram `docs/`-এ |
| `04b7063` | 2026-11-18 | shoplite-app-এর README: চালানো, layout, AWS, setting, secret, test, প্রমাণের index, deviation log |

সব commit GitHub-এর `main`-এ push করা আছে।

## 9. কোথায় কী আছে

```text
devops-final/
├── PLAN.md, project.md, PROGRESS.md      পরিকল্পনা, প্রশ্নপত্র, এই log
├── shoplite-app/
│   ├── README.md                         grader-এর জন্য: চালানো, layout, AWS, setting, test, প্রমাণের index, deviation log
│   ├── docker-compose.yml                ৫টা component: web, catalog-api, order-worker, postgres, redis
│   ├── Makefile                          build, up, down, test, smoke
│   ├── scripts/smoke-test.sh             stack চালু → readyz → order → COMPLETED
│   ├── scripts/bootstrap-cluster.sh      নতুন cluster-এ একবার: namespace, DB-র Secret, Grafana-র Secret, Slack-এর webhook-এর Secret, ArgoCD, root app (Q7, 7.2; Q6)
│   ├── scripts/loadtest.js               k6-এর load test: catalog ১৬/s আর order ৬/s, নির্দিষ্ট হারে (Q6, Q8)
│   ├── scripts/update-gitops.sh          CI: shoplite-gitops-এ এক environment-এর image registry আর tag commit ও push (Q7, 7.4)
│   ├── scripts/tests/                    রিহার্সাল: bootstrap (local k3s, test-এর Git server, lab machine-এর tools); pipeline (actionlint, pin, update-gitops, promote)
│   ├── .github/workflows/main.yml        main pipeline: build → OIDC দিয়ে ECR → gitops-এ dev-এর tag (Q7a; repo ভাগের পরে চলে)
│   ├── .github/workflows/promote.yml     "Run workflow" বোতাম: dev-এর image gitops-এ prod-এর values-এ (Q7, 7.5)
│   ├── .env.example                      local-এর setting (WEB_PORT সহ); আসল .env Git-এ যায় না
│   ├── monitoring/stack/                 Q6-এর chart-গুলোর values: kube-prometheus-stack, loki, tempo, alloy (Alloy-র log pipeline সহ); ArgoCD shoplite-gitops-এর apps/ থেকে পড়ে
│   ├── monitoring/dashboards/            golden-signals.json: "ShopLite — Golden Signals" (Q6, 6.3)
│   ├── monitoring/alert-rules/           shoplite-alerts.yaml: ৫টা alert (PrometheusRule); tests/: promtool-এর unit test আর run.sh (Q6, 6.4)
│   ├── monitoring/runbooks/              ৫টা runbook, প্রতিটা alert-এর নামে (Q6, 6.4)
│   ├── monitoring/kustomization.yaml     dashboard থেকে ConfigMap (Grafana-র sidecar তোলে), আর alert-এর PrometheusRule; ArgoCD-র monitoring-config পড়ে
│   ├── helm/shoplite/                    Q5-এর chart: Chart.yaml, values.yaml, values-dev.yaml, values-prod.yaml
│   │   ├── files/init.sql                table আর seed (Compose আর Kubernetes দুটোই এটা ব্যবহার করে)
│   │   └── templates/                    web, catalog-api (+ PDB), order-worker (+ HPA, metrics-এর Service), postgres, redis, ingress, networkpolicy, servicemonitor, configmap, _helpers
│   ├── helm/tests/run.sh                 chart-এর রিহার্সাল: local k3s-এ install, যাচাই, শেষে সব মোছে
│   ├── docs/evidence/q4/commands.md      Q4 lab-এ চালানোর পদ্ধতি, প্রমাণ আর screenshot-এর তালিকা (screenshot-ও এখানে)
│   ├── docs/evidence/q5/commands.md      Q5-এর পদ্ধতি: একবার repo ভাগ আর GitHub-এর setting; প্রতি session-এ pipeline, bootstrap, promote, prod-এর sync, প্রমাণ
│   ├── docs/evidence/q6/commands.md      Q6-এর পদ্ধতি: k6, Grafana, ৬a–৬e-র প্রমাণ, Slack-এ alert, ভিডিও V3 (alert থেকে ব্যর্থ request)
│   ├── docs/evidence/q7/commands.md      Q7-এর পদ্ধতি: pipeline, Trivy-র লাল run, PR আর plan-এর comment, ArgoCD, self-heal (V5), checkpoint (V4)
│   ├── docs/evidence/q8/commands.md      Q8-এর পদ্ধতি: peer-এর access, load-এ সুস্থ শুরু, peer-এর commit, শুধু Grafana দিয়ে তদন্ত, Git revert, recovery, RCA-র সংখ্যা, peer-এর অংশ
│   ├── docs/RCA.md                       RCA-র কাঠামো (TODO); Q8-এর exercise-এর পরে লেখা হবে
│   ├── docs/architecture-diagram.md      তিনটা mermaid ছবি (infrastructure, delivery, observability), সাথে তিনটা PNG
│   ├── linux/                            Q3
│   │   ├── sshd_config                   root আর password login বন্ধ
│   │   ├── systemd/                      shoplite-backup.service, .timer, .sh (রাতে pg_dump)
│   │   ├── firewall/ufw.sh               deny incoming; শুধু 22, 80, 443
│   │   └── evidence/commands.md          lab-এর command, প্রত্যাশিত output, screenshot-এর তালিকা
│   ├── ansible/                          Q4 (g)
│   │   ├── site.yml, ansible.cfg         playbook: hardening → k3s → kubeconfig
│   │   ├── requirements.txt, .yml        pin করা ansible-core আর collection
│   │   ├── group_vars/                   VPC, cluster-এর port, control-plane-এর 6443
│   │   ├── roles/hardening/              Q3-এর 3.1, 3.2, 3.4 প্রতিটা node-এ
│   │   ├── roles/container_runtime/      kernel module, sysctl, pin করা k3s binary (containerd সহ), ECR-এর credential provider
│   │   ├── roles/k3s_server/             control-plane: config, systemd unit, Traefik বন্ধ
│   │   ├── roles/k3s_agent/              worker: server থেকে token নিয়ে join
│   │   ├── roles/kubeconfig/             admin kubeconfig Ansible-এর machine-এ আনা
│   │   └── tests/                        ৩টা local node-এ রিহার্সাল (run.sh, verify.yml)
│   ├── terraform/                        Q4
│   │   ├── bootstrap/                    state-এর S3 bucket (একবার, account প্রতি)
│   │   ├── q3-server/                    Q3-এর EC2, নিজের ছোট VPC-তে (+ নিজের tests/)
│   │   ├── backend.tf                    S3 backend, use_lockfile
│   │   ├── main.tf, variables.tf         provider, project=shoplite tag, USD 20 budget, module-গুলো জোড়া
│   │   ├── outputs.tf                    VPC আর subnet-এর id, node-এর instance id, app-এর URL, ECR-এর URL, Ansible-এর inventory, kubectl-এর tunnel, CI-এর role (`ci_role_arn`)
│   │   ├── templates/inventory.ini.tftpl lab-এর inventory: node instance id দিয়ে, SSH SSM-এর ভেতর দিয়ে
│   │   ├── modules/network/              VPC, subnet, IGW, NAT, route table (+ নিজের tests/)
│   │   ├── modules/compute/              node-এর security group, IAM role, key pair, ৩টা EC2 (+ নিজের tests/)
│   │   ├── modules/alb/                  ALB, listener, target group, ALB → node-এর rule (+ নিজের tests/)
│   │   ├── modules/ecr/                  তিনটা image repository (+ নিজের tests/)
│   │   ├── modules/github-oidc/          GitHub-এর OIDC provider আর CI-এর role, শুধু ECR-এ push (Q7, 7.3; + নিজের tests/)
│   │   └── tests/                        terraform test, mock provider
│   └── services/
│       ├── web/
│       │   ├── public/                   index.html, app.js, style.css: page
│       │   ├── nginx/default.conf.template  /api proxy, no-cache, /healthz, JSON log
│       │   ├── tests/                    image-এর ১৫টা check, fake API
│       │   └── Dockerfile                test → runtime
│       ├── catalog-api/app/
│       │   ├── main.py                   সব endpoint
│       │   ├── faults.py                 CHAOS_LATENCY_MS, CHAOS_ERROR_RATE
│       │   ├── db.py                     Postgres query আর DB span
│       │   ├── order_queue.py            Redis queue, traceparent সহ message
│       │   ├── middleware.py             প্রতি request-এ log আর HTTP metric
│       │   ├── metrics.py                ৪টা metric
│       │   ├── tracing.py                OpenTelemetry setup
│       │   ├── logging_setup.py          JSON log
│       │   └── config.py                 env থেকে config
│       └── order-worker/worker/
│           ├── main.py                   consumer loop, SIGTERM
│           ├── processor.py              একটা order process করা, consumer span, CHAOS_MEMORY_LEAK
│           ├── store.py                  status update আর DB span, CHAOS_SLOW_DB
│           ├── metrics.py                ২টা metric
│           ├── http_server.py            :8001 /healthz, /metrics
│           └── tracing.py, logging_setup.py, config.py, order_queue.py
└── shoplite-gitops/                      ArgoCD-র desired state (শেষে আলাদা repo)
    ├── bootstrap/argocd-values.yaml      ArgoCD-র setting: /argocd, Git দেখা ৬০ সেকেন্ডে, Application-এর health
    ├── bootstrap/root-app.yaml           root Application ("app of apps"), bootstrap একবার বসায়
    ├── apps/                             traefik, kube-prometheus-stack, loki, tempo, alloy (wave 0), shoplite-dev (auto-sync, self-heal), shoplite-prod (manual), monitoring-config (dashboard; wave 1)
    └── envs/                             dev/values.yaml (CI লেখে image tag), prod/values.yaml (tag, Q8-এর flag)
```

## 10. Local-এ চালানো আর দেখা

Linux-এ, `shoplite-app` folder থেকে (প্রশ্নের checkpoint):

```bash
make up && make smoke
```

Windows-এর Git Bash-এ `make` নেই। সেখানে একই কাজ এভাবে (প্রথম লাইন একবারই):

```bash
cp .env.example .env
```

```bash
docker compose up -d --build --wait && sh scripts/smoke-test.sh
```

PC-01-এ আসল `make` চালাতে WSL-এর Ubuntu ব্যবহার করা যায়:

```bash
wsl.exe -d Ubuntu --cd /mnt/e/devops-final/shoplite-app -- make up
```

| কী দেখবে | কোথায় |
|---|---|
| Page | PC-01-এ http://127.0.0.1:8088 (কারণ `.env`-এ `WEB_PORT=127.0.0.1:8088`); port 80 ফাঁকা থাকলে http://localhost |
| API, web-এর ভেতর দিয়ে | `/api/products`, `/api/readyz`, `/api/metrics` (page-এর ঠিকানার পরে) |
| Worker-এর metric | `docker compose exec order-worker wget -qO- http://127.0.0.1:8001/metrics` |
| Log | `docker compose logs -f` |

একটা chaos flag চালু করে দেখতে (যেমন slow DB):

```bash
CHAOS_SLOW_DB=true docker compose up -d --wait
```

বন্ধ করতে flag ছাড়া আবার `docker compose up -d --wait`। অথবা `.env`-এ লাইন বসাও; `.env.example`-এ চারটাই লেখা আছে।

Unit test: `make test`। অথবা কোনো একটা service-এর folder থেকে (যেমন `services/catalog-api`):

```bash
docker build --target test -t test-image . && docker run --rm test-image
```

বন্ধ করতে `make down` বা `docker compose down`; data volume থেকে যায়।

Terraform-এর test, `shoplite-app` থেকে, Docker-এ (Windows Git Bash-এ; Linux-এ `$(pwd -W)`-এর বদলে `$PWD`):

```bash
MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W)/terraform:/tf" -w /tf hashicorp/terraform:1.17.2 init -backend=false
```

```bash
MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W)/terraform:/tf" -w /tf hashicorp/terraform:1.17.2 test
```

`bootstrap`-এর জন্য একই command, শুধু `-chdir=bootstrap` যোগ করে। সব ফাইলের format দেখতে: `fmt -check -recursive`।

Helm chart-এর রিহার্সাল (Docker আর internet লাগে; local k3s-এ gitops-এর Traefik আর chart-এর dev ও prod বসিয়ে যাচাই, শেষে সব মোছে; প্রায় ১০ মিনিট), `shoplite-app` থেকে:

```bash
bash helm/tests/run.sh
```

GitOps-এর রিহার্সাল (Docker আর internet লাগে; local k3s-এ `scripts/bootstrap-cluster.sh` চালায়, তারপর ArgoCD নিজে Traefik, monitoring stack (metrics, Loki, Tempo, Alloy), dev আর prod বসায়; যাচাই করে, শেষে সব মোছে; অফিসের PC-তে প্রায় ১৩ মিনিট; বাসার PC-তে আরও বেশি), `shoplite-app` থেকে:

```bash
bash scripts/tests/bootstrap-cluster.sh
```

Pipeline-এর রিহার্সাল (Docker আর internet লাগে; দুই workflow-এর actionlint আর action-এর pin, `update-gitops.sh`, promote-এর step, dev আর prod-এর chart-এর image; প্রায় ২০ সেকেন্ড), `shoplite-app` থেকে:

```bash
bash scripts/tests/pipeline.sh
```

Alert-এর unit test (Docker লাগে; ৫টা alert-এর নাম, severity আর runbook, তারপর promtool; প্রায় ১০ সেকেন্ড), `shoplite-app` থেকে:

```bash
bash monitoring/alert-rules/tests/run.sh
```

Ansible-এর রিহার্সাল (Docker আর internet লাগে; ৩টা node-এ hardening আর k3s, দুইবার run, যাচাই, শেষে সব মোছে; ৫–১০ মিনিট), `shoplite-app` থেকে:

```bash
bash ansible/tests/run.sh
```

## 11. পথে নেওয়া সিদ্ধান্ত (demo আর README-র deviation log-এ লাগবে)

- **শুধু প্রশ্নে যা চাওয়া, সেটুকুই (12 Nov, user-এর সিদ্ধান্ত)।** সুবিধার জন্য বাড়তি tool বা feature যোগ হবে না, সময় লাগলেও কাটছাঁট নয়। প্রকল্প reproducible করতে যে ফাইল লাগে, সেগুলো রাখা যায়, কারণ প্রশ্নই তার অনুমতি দেয়। এই নিয়মে Q2-তে সরানো হয়েছে: Jaeger, compose-এর OTEL endpoint, catalog-api-র host port, web-এর version footer আর heading-এ `<title>` copy করা।
- **Worker product-এর stock কমায় না।** কমালে Q8-এর ১৫ মিনিটের load test-এ stock শেষ হয়ে সব order `FAILED` হতো, আর তদন্ত গুলিয়ে যেত।
- **Probe আর scrape request HTTP metric আর trace-এ গোনা হয় না।** `/healthz`, `/readyz`, `/metrics` কয়েক সেকেন্ড পরপর আসে, এগুলো আসল traffic চাপা দিত।
- **`/readyz`-এর 503 log হয় WARNING হিসেবে, ERROR না।** তাই Q8-এ ERROR log মানে আসল application error।
- **Queue depth Redis থেকে scrape-এর মুহূর্তে পড়া হয়।** Redis-এ না পৌঁছালে মান `NaN`, পুরনো সংখ্যা দেখায় না।
- **DB span নিজে লেখা, auto-instrumentation না।** Auto-instrumentation `/readyz`-এর প্রতিটা `SELECT 1`-এর জন্য আলাদা trace বানাত।
- **`init.sql` রাখা Helm chart-এর ভেতরে**, যাতে Compose আর Kubernetes একই ফাইল ব্যবহার করে।
- **Test-এ `httpx`-এর বদলে `httpx2`।** Starlette 1.x এটাই চায়।
- **Trace পাঠানো হয় শুধু OTLP দিয়ে, `OTEL_EXPORTER_OTLP_ENDPOINT` থাকলে।** Kubernetes-এ এটা হবে Tempo-র ঠিকানা। Compose-এ trace-এর কোনো backend নেই (প্রশ্নে চাওয়া হয়নি), তাই সেখানে span তৈরি হয়, কিন্তু কোথাও পাঠানো হয় না; log-এ `trace_id` থাকে।
- **Chaos flag-এর নাম কোথাও ছাপা হয় না।** Log, 500-এর body বা span-এর নাম, কোথাও না; Q8-এ কারণ বের করতে হবে লক্ষণ দেখে। যে comment-এ flag-এর নাম আছে, সেটা চলমান code-এর লাইনের পাশে না রেখে আলাদা লাইনে রাখা হয়েছে, কারণ exception হলে traceback ওই লাইনটা ছাপায়। ব্যতিক্রম শুধু ভুল মান: তখন service চালু হওয়ার সময়ই থেমে যায়, error-এ variable-এর নাম থাকে।
- **Latency-র নিজের কোনো span নেই।** Trace-এ সেটা DB span-এর আগের ফাঁক হিসেবে দেখা যায়, আসল কোনো bug-এর মতো।
- **Memory leak-এ non-zero byte।** শূন্য দিয়ে ভরা memory Linux অনেক সময় সত্যিই খরচ করে না, তখন pod-এর memory বাড়ত না।
- **Random source বাইরে থেকে দেওয়া যায়** (`FaultInjector`-এর `rng` আর `sleep`)। তাই test-এ ঠিক করে দেওয়া যায় কোন request-এ দেরি বা error হবে।
- **কাজের ক্রম (12 Nov):** আগে অ্যাপ পুরো শেষ (Q1, Q2), তারপর Terraform, Ansible, Helm, monitoring আর CI। ওগুলোর code নিজের PC-তেই লেখা হবে; lab-এ শুধু চালানো আর প্রমাণ নেওয়া।
- **Web চলে uid 101-এ, বাকি দুইটা 10001-এ।** 101 হলো `nginx-unprivileged` image-এর নিজের non-root user; বদলালে nginx-এর লেখার folder-গুলোর permission নতুন করে ঠিক করতে হতো।
- **Web-এর config container চালু হওয়ার সময় তৈরি হয়।** Image-এর entrypoint template থেকে `API_UPSTREAM` আর DNS server বসায়। `proxy_pass`-এ variable থাকায় nginx নাম খোঁজে প্রতি request-এ, তাই catalog-api না থাকলেও চালু হয়। Kubernetes-এ `API_UPSTREAM`-এ পুরো নাম দিতে হবে (`catalog-api.<namespace>.svc.cluster.local:8000`), কারণ nginx-এর resolver search domain মানে না। Kubernetes-এ অবশ্য `/api` সরাসরি Traefik থেকে catalog-api-তে যাবে (PLAN Phase 6)।
- **Page-এর সব ফাইলে `Cache-Control: no-cache`।** Q7-এ `<title>` বদলালে পরের reload-এই browser-এ নতুন title দেখা যাবে।
- **Worker process-এর সংখ্যা CPU limit অনুযায়ী** (`NGINX_ENTRYPOINT_WORKER_PROCESSES_AUTOTUNE`)। `auto` দিলে nginx পুরো machine-এর CPU গুনে PC-01-এ ২৮–৩২টা process চালু করত।
- **বাইরে খোলা শুধু web।** catalog-api-তে পৌঁছানো যায় web-এর `/api` দিয়ে, প্রশ্নের architecture-এর মতো (frontend → catalog-api)। Docker তার published port-এর বেলায় UFW মানে না, তাই এতে Q3-এর firewall-এর নিয়মও সত্যি থাকে।
- **`WEB_PORT`-এ শুধু port অথবা `IP:PORT` দেওয়া যায়।** `127.0.0.1:8088` দিলে page শুধু ওই machine থেকেই খোলা যায়। PC-01-এ এটাই দেওয়া, কারণ সেখানে port 80 ব্যস্ত।
- **API আর worker-এর virtualenv-এ নিজের pip নেই।** Runtime-এ pip কখনো লাগে না, অথচ 13 MB নিত; সরানোর পর `docker images`-এর সব সংখ্যা 150 MB-এর নিচে।
- **Smoke test চলে web-এর ভেতর দিয়ে** (`/api/readyz`, `/api/orders`)। তাই এক পরীক্ষাতেই web, API, Postgres, Redis আর worker সবই যাচাই হয়। Port নেয় compose থেকে, তাই `WEB_PORT` যা-ই থাকুক চলে।
- **`make test` প্রতিটা service-এর Dockerfile-এর test stage চালায়,** তাই machine-এ Python লাগে না।
- **sshd-র নিষেধগুলো `Include`-এর আগে।** sshd প্রতিটা setting-এর প্রথম মান রাখে, আর EC2-র Ubuntu-তে `sshd_config.d/`-এ cloud-এর নিজের ফাইল থাকে। আগে রাখায় কোনো drop-in ফাইল এগুলো উল্টাতে পারে না। কার্যকর মান দেখা হয় `sshd -T` দিয়ে।
- **Root-এর login আটকানোর প্রমাণে root-কে সাময়িকভাবে বৈধ key দেওয়া হয়।** তাহলে বোঝা যায় আটকাচ্ছে `PermitRootLogin no`-ই, key না থাকা নয়; sshd-র log-এ আসে `ROOT LOGIN REFUSED`। পরীক্ষা শেষে key সরানো হয়।
- **একটাই `setfacl` rule, আর সেটা default ACL** (`g:ops:rx`)। পরে তৈরি হওয়া ফাইলও শুধু `ops` পড়তে পারে, যে program ফাইল বানাক তার umask যা-ই হোক। সাথে setgid (`chmod 2750`), তাই নতুন ফাইলের group-ও `ops`।
- **Backup চলে postgres container-এর ভেতরে** (`docker compose -p shoplite exec postgres pg_dump`)। Postgres host-এ খোলা নেই, তাই বাইরে থেকে `pg_dump` চালানো যায় না। Database-এর নাম আর user নেওয়া হয় container-এর নিজের env থেকে, তাই script-এ কিছু hard-code করা নেই।
- **Backup সাধারণ `.sql` ফাইল।** Compression আর পুরনো backup মোছা প্রশ্নে চাওয়া হয়নি, তাই নেই। ফাইল শুধু root পড়তে পারে (`umask 077`), কারণ এতে সব order থাকে।
- **`Restart=on-failure`-এর সাথে সীমা দেওয়া** (৫ মিনিট পরপর, এক ঘণ্টায় সর্বোচ্চ ৩ বার)। নইলে কোনো সমস্যা থেকে গেলে সারারাত প্রতি মিনিটে চেষ্টা চলতে থাকত।
- **Blocked port দেখাতে 8000-এ একটা অস্থায়ী listener।** ওই port-এ কিছু শুনছে, তবু বাইরে থেকে timeout হয়, তাই বোঝা যায় আটকাচ্ছে firewall। Lab-এর security group-এ 8000 খোলা রাখা হবে, যাতে আটকানোটা শুধু UFW-র কাজ হয়।
- **`linux/evidence/commands.md` ইংরেজিতে,** কারণ এটা grader পড়বেন। PROGRESS আর PLAN নিজের জন্য, তাই বাংলায়।
- **Terraform 1.17.2 আর AWS provider 6.73.0, pin করা।** Provider-এর lock ফাইল (`.terraform.lock.hcl`) Git-এ থাকে, তাই lab আর CI ঠিক একই provider পায়।
- **Q4-এর code যাচাই হয় `terraform test` আর mock provider দিয়ে।** AWS-এর credential শুধু lab-এ থাকে, অথচ module-এর logic (নাম, সংখ্যা, setting) আগেই পরীক্ষা করা যায়। Test-গুলো Docker-এর `hashicorp/terraform` image-এ চলে।
- **State bucket-এর নামে account id আর region**, আর সেটা backend-এ দেওয়া হয় `init`-এর সময় (`-backend-config`)। Lab-এর account বদলালেও code বদলাতে হয় না।
- **State bucket-এ শুধু versioning যোগ করা হয়েছে।** Encryption আর public access বন্ধ রাখা এখন S3-এর নতুন bucket-এ এমনিতেই থাকে।
- **Budget পুরো account-এর খরচ দেখে, tag দিয়ে ছাঁকে না।** Tag দিয়ে ছাঁকতে আগে cost allocation tag চালু করতে হয়, যা কার্যকর হতে এক দিন লাগে। Lab-এর account শুধু এই project-এর।
- **Budget-এর email Git-এ নেই;** দেওয়া হয় `TF_VAR_budget_alert_email` দিয়ে।
- **Region আপাতত `ap-southeast-1` (Singapore),** variable হিসেবে। Lab-এ কোন region, সেটা preflight-এ দেখে ঠিক করতে হবে।
- **NAT Gateway একটাই,** প্রথম AZ-এ। দুই AZ-এ দুইটা দিলে একটা AZ বন্ধ হলেও চলত, কিন্তু খরচ দ্বিগুণ। Lab-এর জন্য একটাই যথেষ্ট, আর প্রশ্নও "a NAT Gateway" চায়।
- **কোনো subnet নিজে থেকে public IP দেয় না** (`map_public_ip_on_launch = false`, স্পষ্ট করে লেখা)। ALB আর NAT নিজের ঠিকানা পায়, আর Kubernetes node-এ বাইরে থেকে পৌঁছানো যাবে না (4b)।
- **Module-এর subnet-এর তালিকা variable দিয়ে আসে,** সংখ্যা যেকোনো (কমপক্ষে ২)। প্রশ্ন "reusable modules" চায়, আর test-এ তিন AZ দিয়েও চালিয়ে দেখা হয়েছে।
- **Node-এর জন্য দুইটা security group।**
  - সব node-এর group: node থেকে node-এ ৩টা port।
  - Control-plane-এর group: শুধু 6443।

  তাতে API server-এর port worker-এ খোলা থাকে না। প্রতিটা rule-এর উৎস node-এর group নিজে, কোনো IP range নয়।
- **9100 (node-exporter) এখনই খোলা।** Q6-এ Prometheus অন্য node-এর node-exporter-কে node-এর IP দিয়ে পড়ে; তাই 4.7-এর UFW-তেও 9100 লাগবে, শুধু VPC-র ভেতর থেকে। PLAN-এর তালিকায় 9100 ছিল না।
- **SSH-এর কোনো rule নেই।** Admin access SSM দিয়ে। Ansible (4.7) চলবে SSM-এর ভেতর দিয়ে চলা SSH-এ, যা instance-এর নিজের ভেতরে port 22-এ যায়, তাই security group-এ কিছু খুলতে হয় না।
- **ECR-এর জন্য `AmazonEC2ContainerRegistryPullOnly`, `ReadOnly` নয়।** Image টানতে যতটুকু লাগে, শুধু ততটুকুই।
- **IMDSv2 বাধ্যতামূলক, hop limit 1।** Pod-এর ভেতর থেকে node-এর AWS credential পড়া যায় না।
- **Node-এর disk 30 GiB gp3, encrypted।** AMI-র default 8 GiB-এ k3s, image, Prometheus আর Loki আঁটে না।
- **ALB-র দুইটা listener: 80 (prod) আর 8080 (dev),** PLAN অনুযায়ী। Domain নেই বলে port দিয়ে environment আলাদা। Q7-এর checkpoint-এ auto-sync হওয়া dev-কে browser-এ দেখাতে 8080 লাগে।
- **ALB-র target শুধু worker।** Control-plane user traffic নেয় না; NodePort যেকোনো node-এ চলে, তাই worker-ই যথেষ্ট।
- **Health check ingress-এর (`/ping`), কোনো একটা app-এর নয়।** তাতে একটা app বসে গেলে পুরো ALB-র target unhealthy হয় না।
- **HTTPS নেই।** Domain আর certificate ছাড়া ALB-তে HTTPS দেওয়া যায় না, আর প্রশ্নও চায়নি।
- **ECR repository-র নাম `shoplite/<image>`,** local image-এর নামের মতো। Repo-তে শুধু `force_delete` (destroy-এর জন্য); scan, lifecycle আর immutable tag প্রশ্নে নেই বলে রাখা হয়নি।
- **Q3-এর server নিজের ছোট VPC-তে (user-এর সিদ্ধান্ত, 12 Nov)।** Default VPC অনেক lab account-এ থাকে না, আর মূল VPC-তে রাখলে Q3 শুরু করা যেত Q4-এর পরে। নিজের VPC-তে NAT নেই, তাই খরচও কম।
- **Q3-এর server-এ SSH খোলা (শুধু admin-এর IP থেকে), node-এ নয়।** Q3 নিজেই SSH-এর কাজ: key দিয়ে login, আর root ও password-এর login প্রত্যাখ্যাত হওয়া দেখাতে হয়।
- **`admin_cidr` /24-এর চেয়ে চওড়া হতে পারে না।** ভুল করেও যেন server পুরো internet-এর জন্য খুলে না যায়।
- **ansible-core 2.21.6, 2.22 নয়।** 2.22-এর controller-এ Python 3.13 লাগে, আর lab-এর Ubuntu 24.04-এ আছে 3.12।
- **Node-এ `sshd_config` সরাসরি `linux/sshd_config` থেকে।** Q3-এর server আর node-এ একই ফাইল, তাই দুইটা কখনো আলাদা হয়ে যায় না। UFW-এর মূল নিয়ম `linux/firewall/ufw.sh`-এর মতো; Ansible-এ `ufw` module দিয়ে, যাতে idempotent থাকে।
- **Node-এর UFW-এ k3s-এর pod আর service network থেকে সব খোলা।** একই node-এর pod যখন node-এর IP-তে যায় (kubelet, node-exporter, API), তখন source থাকে pod-এর IP, VPC-র নয়। k3s-এর docs-এ UFW-এর জন্য এটাই বলা। NodePort-এর traffic forward হয়, তাই forward policy ACCEPT। এটা README-র deviation log-এ যাবে।
- **`host_key_checking = False`।** Node প্রতি lab session-এ নতুন, আর পৌঁছানো হয় SSM দিয়ে, যা instance-এর পরিচয় নিজেই যাচাই করে।
- **Ansible-এর test-এর ব্যবস্থা repo-তে (`ansible/tests/`)।** Product-এর অংশ নয়, তবে service-এর test-এর মতোই code-এর test; পরের role যোগ হলে আবার চালানো যাবে।
- **k3s বসে সরাসরি release থেকে, install script দিয়ে নয়।** Binary-র checksum মেলানো হয়, আর systemd unit Ansible-এর template। Script প্রতিবার internet থেকে নতুন code চালাত; এখন প্রতিটা ফাইল চেনা, আর দ্বিতীয় run-এ কিছুই বদলায় না।
- **k3s `v1.37.2+k3s1`** (13 Nov-এর stable channel, Kubernetes 1.37)। Server আর agent-এর version এক জায়গায়, `group_vars/k3s_cluster.yml`-এ।
- **Container runtime হলো k3s-এর ভেতরের containerd।** আলাদা containerd package নেই। `container_runtime` role kernel প্রস্তুত করে, binary বসায়, আর k3s চালুর পরে containerd-এর version যাচাই করে। README-র deviation log-এ যাবে।
- **Join token Git-এ নেই।** k3s প্রথম চালুর সময় নিজেই বানায়, agent প্রতিবার চলমান server থেকে পড়ে। যে config ফাইলে token থাকে, সেটা শুধু root পড়তে পারে।
- **একটা node fail করলে পুরো playbook থামে** (`any_errors_fatal`)। অর্ধেক তৈরি cluster আসল error ঢেকে দেয়; যেমন রিহার্সালে cp1-এর download fail করার পরেও worker-রা join করতে গিয়েছিল।
- **kubeconfig-এর API ঠিকানা `https://127.0.0.1:6443`।** Node-এর public IP নেই; kubectl চলবে SSM port-forward দিয়ে, আর k3s-এর certificate 127.0.0.1-এর জন্য বৈধ।
- **Ansible node-এ পৌঁছায় SSM-এর ভেতর দিয়ে চলা SSH-এ, bastion দিয়ে নয়।** প্রশ্নই বলে "SSM preferred"। Node-এ key থাকে শুধু login-এর জন্য; port 22 কোথাও খোলা নয়।
- **Inventory আসে Terraform-এর output থেকে, dynamic inventory plugin থেকে নয়।** `amazon.aws.aws_ec2` plugin-এর জন্য controller-এ boto3 আর আরেকটা collection লাগত। Output-এর inventory সাধারণ লেখা ফাইল, আর তার আকার `terraform test`-এ যাচাই করা যায়।
- **Lab-এর জন্য এক-command-এর script নেই, শুধু লেখা পদ্ধতি (14 Nov)।** প্রশ্ন script চায় না, আর নিয়ম হলো প্রশ্নে যা চাওয়া শুধু সেটুকু। Document-এর প্রতিটা ধাপ grader পড়ে মেলাতে পারেন। PLAN-এর `make lab-up` user চাইলে পরে যোগ হতে পারে।
- **প্রতিটা প্রশ্নের lab-এর পদ্ধতি থাকবে `docs/evidence/qN/commands.md`-এ, screenshot-ও সেখানে।** ব্যতিক্রম Q3: সেটা `linux/evidence/`-এ, কারণ প্রশ্নের tree-তে ওই folder-এর নাম দেওয়া।
- **Chart-এর object-গুলোর নাম স্থির** (`web`, `catalog-api`, `postgres`, ...), release-এর নামে নয়। প্রতিটা environment নিজের namespace-এ একটাই release, তাই নাম মিলে যাওয়ার ভয় নেই। App-এর setting-এও (`POSTGRES_HOST=postgres`, `redis://redis:6379/0`) সেই সহজ নামই থাকে, Compose-এর মতো।
- **DB-র Secret chart বানায় না।** ArgoCD Git থেকে values পড়ে, তাই chart যা বানায় তার মান Git-এ থাকতে হতো। বদলে Secret cluster-এ আগে বানানো হয় (lab-এর পদ্ধতিতে থাকবে), chart শুধু নাম ধরে পড়ে।
- **Pod-এর security "restricted" ধরনের:** non-root, seccomp `RuntimeDefault`, privilege escalation বন্ধ, সব capability বাদ। Root filesystem read-only করা হয়নি: প্রশ্নে চাওয়া হয়নি, আর web-এর nginx চালু হওয়ার সময় নিজের config লেখে।
- **Postgres আর Redis-এর official image, Bitnami নয়** (PLAN)। Non-root-এ চলে image-এর নিজের user দিয়ে: Postgres 70, Redis 999।
- **Probe শুধু catalog-api-তে নয়:** web আর worker-এর liveness/readiness-ও আছে, কারণ Docker-এর `HEALTHCHECK` Kubernetes মানে না; এগুলো সেই একই পরীক্ষা। Postgres আর Redis-এরও probe আছে, যাতে তারা সত্যিই সাড়া দিলে তবেই ready হয়।
- **Chart-এর রিহার্সাল repo-তে (`helm/tests/run.sh`),** Ansible-এর `tests/`-এর মতো। Local k3s-এর version lab-এর সাথে মেলে (v1.37.2), Helm 4.3.1 (Docker image `alpine/helm`)।
- **Traefik-এর setting shoplite-gitops-এ** (`apps/traefik.yaml`; user-এর সিদ্ধান্ত, 14 Nov, PLAN অনুযায়ী)। ArgoCD-র Application-এর ভেতরেই values (`valuesObject`), তাই অন্য কোনো repo-র ওপর নির্ভর নেই। Chart 42.2.0 নেওয়া হয়েছে, কারণ সর্বশেষ 42.4.0 তখন মাত্র দুই দিনের পুরনো। Shoplite-app-এর রিহার্সাল পাশের `../shoplite-gitops` থেকে ফাইলটা পড়ে (`SHOPLITE_GITOPS_DIR` দিয়ে বদলানো যায়)।
- **Worker-এর HPA দুই environment-এই ১ থেকে ৪** (user-এর সিদ্ধান্ত, 14 Nov: প্রশ্ন যা বলে)। লক্ষ্য CPU request-এর 70%।
- **Environment আলাদা হয় Traefik-এর entrypoint দিয়ে, host দিয়ে নয়।** Domain নেই; ALB-র port 80 যায় `web` entrypoint-এ (prod), 8080 যায় `dev`-এ।
- **ALB-র health check Traefik-এর `/ping`, কোনো app-এর নয়।** Chart-এর নিজের `ingressRoute.healthcheck` দিয়ে `web` আর `dev` entrypoint-এ খোলা। Traefik-এর নিজের probe ভেতরের entrypoint-এই থাকে।
- **PDB-র প্রমাণ `kubectl drain` দিয়ে।** Node cordon হয়, তাই সরানো pod-এর বদলি Pending থাকে, আর দ্বিতীয় eviction PDB আটকায়। Lab-এর পদ্ধতিতেও এই পরীক্ষাই থাকবে।
- **দুই repo আপাতত `devops-final`-এর দুটো folder, শেষে আলাদা** (user, 14 Nov)। Code শেষের URL ধরে লেখা। ArgoCD আর pipeline লাগে এমন lab session-এর আগে ভাগ করতে হবে (section 7)।
- **GitOps-এর ভিত Q5-এর lab-এর আগে** (user, 14 Nov, PLAN-এর পথ)। Image ECR-এ যায় pipeline দিয়ে, cluster-এ সব বসায় ArgoCD; হাতে `helm install` নেই।
- **Values তিন স্তরে, ArgoCD multi-source দিয়ে:** chart-এর default → shoplite-app-এর `values-<env>.yaml` → gitops-এর `envs/<env>/values.yaml`। Environment-এর স্থায়ী setting app repo-তে থাকে; যা বদলায় (image tag, Q8-এর flag), তা gitops-এ।
- **`envs`-এর values শুরুতে ফাঁকা।** Chart তখন `image.tag is required`-এ থামে। ভুল বা পুরনো image নিয়ে pod চালু হওয়ার চেয়ে পরিষ্কার error ভালো।
- **Prod manual sync, তাই self-heal dev-এ** (ArgoCD-তে self-heal শুধু automated sync-এর সাথে চলে; PLAN)। README-র deviation log-এ যাবে।
- **Sync wave আর retry:** Traefik আগে (wave 0), ShopLite পরে (wave 1); কিছু তখনো না থাকলে sync ব্যাকঅফ দিয়ে আবার চেষ্টা করে।
- **NetworkPolicy শুধু Postgres আর Redis-এ, শুধু আসা traffic-এ** (প্রশ্ন এটুকুই চায়)। "সবকিছু বন্ধ, তারপর একটা একটা খোলা" ধরনের default-deny বা বের হওয়া traffic-এর নিয়ম নেই।
- **অনুমতি শুধু একই namespace-এর pod-কে** (`namespaceSelector` নেই)। তাই dev আর prod একই cluster-এ থাকলেও একে অপরের database-এ পৌঁছাতে পারে না।
- **ECR-এর credential আসে kubelet-এর credential provider থেকে, pull secret থেকে নয়।** ECR-এর token ১২ ঘণ্টায় শেষ হয়, তাই secret বারবার বদলাতে হতো। Plugin প্রতিবার node-এর role দিয়ে নতুন token নেয়, আর কিছু কোথাও জমা থাকে না।
- **`k3s_kubelet_args` lab-এ ফাঁকা।** শুধু রিহার্সাল এতে `fail-cgroupv1=false` দেয়, যখন Docker host cgroup v1-এ চলে।
- **ArgoCD-র values shoplite-gitops-এর `bootstrap/argocd-values.yaml`-এ।** PLAN-এর উদাহরণ ধরে এটা Claude-এর প্রস্তাব; user চাইলে অন্য জায়গায় নেওয়া যায়। এতে cluster-এর সব desired state এক repo-তে থাকে, bootstrap script শুধু ফাইলটা পড়ে।
- **ArgoCD chart 10.11.6 (ArgoCD v3.5.6), pin করা।** তখনকার release-গুলোর মধ্যে দুই সপ্তাহের বেশি পুরনো সর্বশেষটা।
- **DB-র Secret bootstrap বানায়, আগে থাকলে রেখে দেয়।** Postgres প্রথম চালুর password data-তে রেখে দেয়; নতুন password দিলে app আর ঢুকতে পারত না।
- **ArgoCD `/argocd`-এ, host ছাড়া, plain HTTP-তে।** ALB-র DNS নাম প্রতি session-এ বদলায়, আর domain বা certificate নেই। Login ছাড়া API 401 দেয়; admin-এর password শুধু cluster-এ থাকে।
- **Application-এর health check চালু (PLAN)।** ArgoCD 1.8 থেকে Application-এর health নিজে দেখে না; তখন wave শুধু ক্রম ঠিক করত, অপেক্ষা করত না। শেষ wave-এর জন্য root অপেক্ষা করে না, তাই prod OutOfSync থাকলেও root-এর sync শেষ হয় (রিহার্সালে দেখা)।
- **Ingress-এর health check ArgoCD-তে, সবসময় Healthy।** Traefik NodePort-এর পেছনে, ALB Terraform-এর, তাই Ingress-এ load balancer-এর ঠিকানা কখনো আসে না। এটা ছাড়া প্রতিটা app চিরকাল "Progressing" দেখাত। README-র deviation log-এ যাবে।
- **রিহার্সালে prod-এর manual sync ArgoCD-র API দিয়ে** (`POST /argocd/api/v1/applications/shoplite-prod/sync`, admin-এর token দিয়ে)। UI-র Sync button ঠিক এটাই পাঠায়; lab-এ sync হবে UI থেকে।
- **রিহার্সালের Git server-এর IP স্থির (172.30.0.10), আর repo থাকে তার container-এর ভেতরে।** k3s-এর CoreDNS Docker-এর container-এর নাম চেনে না। আর host-এর %TEMP%-এ রাখা repo বাসার PC-র কোনো cleaner ভেঙে দিয়েছিল (section 12)।
- **CI-এর role নিতে পারে শুধু shoplite-app-এর `main`** (হুবহু মেলানো, wildcard নেই)। প্রশ্নের main-branch pipeline-ই শুধু push করে। PR pipeline (Q7b)-এর Terraform plan-এর জন্য পরে আলাদা, শুধু পড়ার অনুমতির role লাগবে; push-এর role PR-কে দেওয়া হবে না।
- **Role-এর অনুমতি শুধু push**, AWS-এর docs-এর ছয়টা action, শুধু তিনটা repo-তে। ব্যতিক্রম শুধু login (`GetAuthorizationToken`), যা AWS repo দিয়ে সীমিত করতে দেয় না।
- **OIDC provider-এ thumbprint নেই।** GitHub-এর জন্য AWS নিজের বিশ্বস্ত CA দিয়ে certificate যাচাই করে; pin করা thumbprint GitHub certificate বদলালে পুরনো হয়ে যেত। Provider 6.73-এ এটা optional (`validate` pass)।
- **OIDC-এর role root config-এ, Q4-এর একই apply-এ।** ECR-এর ARN সরাসরি module থেকে আসে, আর lab-এ আলাদা init বা apply লাগে না।
- **Pipeline-এর setting** (user-এর সিদ্ধান্ত, 15 Nov):
  - Role-এর ARN shoplite-app-এর Actions variable `AWS_ROLE_ARN`-এ; এটা secret নয়।
  - gitops-এ লেখা হবে deploy key দিয়ে (secret `GITOPS_DEPLOY_KEY`)। এর অনুমতি শুধু shoplite-gitops-এ, আর key কারো account-এর সাথে বাঁধা নয়।
  - Region `AWS_REGION`, না দিলে `ap-southeast-1` (Terraform-এর default)।
- **`LAB_ACTIVE` (PLAN):** `true` না হলে pipeline শুধু build করে। Lab-এর বাইরে AWS-এর role বা ECR থাকে না, তখনো run সবুজ থাকে।
- **এক job, matrix নয়।** পরে Trivy যে image scan করবে, push হবে ঠিক সেটাই; আবার build করলে অন্য image হতে পারত। OIDC login-ও একবার।
- **Tag সবসময় string** (`strenv()`): `0123456` বা `1e23456` number হয়ে গেলে chart ভুল image নাম লিখত।
- **"Run workflow" বোতাম (`workflow_dispatch`)** (user-এর সিদ্ধান্ত, 15 Nov, খালি commit-এর বদলে)।
  - প্রতি lab session-এর শুরুতে ECR খালি থাকে। তখন Actions tab থেকে main-এর ওপর একবার চালানো হয়।
  - প্রশ্ন এটা চায় না, তাই README-র deviation log-এ যাবে।
  - অন্য branch থেকে চালালে CI-এর role পাওয়া যায় না (trust শুধু `refs/heads/main`)।
- **prod-এ তোলা `promote` workflow দিয়ে, 5.4-এর আগে** (user-এর সিদ্ধান্ত, 15 Nov; PLAN-এর পথ)।
  - যা dev-এ চলছে, শুধু সেটাই prod-এ যায়। Input নেই।
  - AWS লাগে না, তাই lab machine-এ GitHub-এর credential বা yq লাগে না।
  - prod-এর chaos flag ছোঁয় না; Q8-এর peer-এর commit থাকে।
- **Repo ভাগের সময় shoplite-app-এর `test.md` বদলে যাবে** (user-এর সিদ্ধান্ত, 15 Nov)। Force push করা হবে `git subtree split`-এর history দিয়ে। GitHub-এর shoplite-app-এ থাকবে শুধু আমাদের code আর তার history।
- **দুই repo public** (5.4)। ArgoCD-তে repo-র কোনো credential রাখা হয়নি, তাই সে GitHub থেকে credential ছাড়াই পড়ে। Private রাখতে চাইলে ArgoCD-কে একটা read-only deploy key দিতে হবে; সেটা এখন নেই।
- **Monitoring-এর setting shoplite-app-এ, Application shoplite-gitops-এ** (6.1; প্রশ্ন বলে monitoring configuration shoplite-app-এ)।
  - প্রতিটা chart-এর values থাকে `monitoring/stack/`-এ।
  - ArgoCD-র Application দুই source থেকে পড়ে: chart আর shoplite-app (`ref: app`)।
- **chart-এর default alert আর dashboard বন্ধ** (6.1)। প্রশ্ন চায় ৫টা alert আর একটা dashboard। Default-গুলো থাকলে Slack-এ অপ্রয়োজনীয় alert যেত।
- **kube-prometheus-stack wave 0-তে** (6.1), কারণ ShopLite-এর ServiceMonitor-এর জন্য তার CRD আগে লাগে। ফলে ShopLite বসে metrics stack Healthy হওয়ার পরে।
- **Grafana ALB-র `/grafana`-এ, admin-এর password cluster-এর Secret-এ** (6.1), ArgoCD-র মতো। Bootstrap Secret-টা একবার বানায়, Git-এর বাইরে। chart নিজে password বানালে ArgoCD প্রতিবার render করার সময় নতুন random password পেত, কারণ সে cluster না দেখেই render করে।
- **order-worker-এর Service শুধু metrics-এর জন্য** (6.1)। প্রশ্ন চায় ServiceMonitor দিয়ে scrape, আর ServiceMonitor Service ধরে খোঁজে।
- **Loki আর Tempo-র chart grafana-community থেকে** (6.1-এ বাছা, PLAN-এর কথামতো)। grafana-র নিজের `loki` chart এখন Enterprise Logs-এর, আর `tempo` chart deprecated।
- **প্রতি session-এ promote, তারপর prod-এর sync** (5.4)। ECR প্রতি session-এ খালি থাকে, আর main-এর run শুধু সর্বশেষ commit-এর image push করে। তাই prod-এর পুরনো tag-এর image না-ও থাকতে পারে; promote prod-কে dev-এর tag-এ আনে।
- **Loki, Tempo আর Alloy-ও wave 0-তে** (6.2)। ShopLite ওঠার আগেই log আর trace নেওয়ার জায়গা তৈরি থাকে, তাই শুরুর span হারায় না। খরচ: monitoring-এর কোনো অংশ Healthy না হলে ShopLite-ও বসে না। রিহার্সালে এটা প্রতিবার যাচাই হয়।
- **Loki-র label: namespace, pod, container, আর JSON থেকে level আর service** (6.2)। PLAN-এর "label শুধু level আর service"-এর মানে ধরা হয়েছে JSON-এর field-এর মধ্যে শুধু এই দুটো।
  - Kubernetes-এর label লাগে, কারণ Loki-র প্রতিটা stream-এ অন্তত একটা label থাকতে হয়, আর JSON নয় এমন log-এ level বা service থাকে না।
  - namespace ছাড়া dev আর prod-এর log আলাদা করা যেত না।
- **Alloy log পড়ে Kubernetes API দিয়ে, node-এর disk থেকে নয়** (6.2; Claude-এর বাছাই)। ফলে host-এর folder mount লাগে না, আর Alloy root ছাড়া চলে। `/var/log/pods` পড়তে হলে root লাগত। এই component (`loki.source.kubernetes`) Alloy 1.21-এ GA, অর্থাৎ stable।
- **Alloy-র RBAC ছোট করা** (6.2)। chart-এর default সব namespace-এর Secret আর ConfigMap পড়তে দেয়; এখন শুধু `pods` আর `pods/log`।
- **Tempo-র OTLP ঠিকানা chart-এর `values.yaml`-এ**, env-এর ফাইলে নয় (6.2)। এক cluster-এ এক Tempo, দুই env-এর জন্য একই ঠিকানা।
  - chart-এর রিহার্সালে Tempo নেই, তাই export ব্যর্থ হয়। exporter-এর log আসে: WARNING `Transient error ...` আর ERROR `Failed to export spans batch ...`।
  - App-এর কাজে প্রভাব পড়ে না। Tempo ছাড়া catalog-api আলাদা চালিয়ে দেখা হয়েছে: request চলে, আর SIGTERM-এ বন্ধ হয় ১ সেকেন্ডে।
- **Dashboard-এ Q8-এর জন্য বাড়তি ৩টা জিনিস** (user-এর সিদ্ধান্ত, 16 Nov; PLAN অনুযায়ী)। Restart আর শেষবার বন্ধের কারণ, সাম্প্রতিক ERROR log, আর deploy-এর দাগ। Q8-এ kubectl চলে না, তাই এগুলো Grafana-তেই থাকা দরকার। প্রশ্নের ৭টা উপরে থাকে, এগুলো আলাদা "Investigation" অংশে।
- **Deploy-এর দাগ annotation হিসেবে** (6.3; Claude-এর বাছাই)। আলাদা panel-এর বদলে সব graph-এর ওপর একসাথে দেখায়, কখন deploy হলো আর তার পরে কী বদলাল।
- **Environment বাছাই custom variable-এ** (`shoplite`, `shoplite-dev`; default prod), Prometheus থেকে খুঁজে নয়। মান দুটো নির্দিষ্ট।
- **`monitoring-config` wave 1-এ** (6.3)। 6.4-এর PrometheusRule-এর CRD kube-prometheus-stack (wave 0) থেকে আসে।
- **Alert Slack-এ, webhook-এর URL শুধু cluster-এ** (6.4; PLAN)।
  - Alertmanager URL পড়ে Secret-এর ফাইল থেকে (`api_url_file`), তাই Git-এর config-এ শুধু path থাকে।
  - Secret বানায় bootstrap, `SLACK_WEBHOOK_URL` থেকে। প্রথমবার এটা না দিলে bootstrap থামে, কারণ Slack ছাড়া alert কোথাও যেত না।
- **error আর latency-র alert route অনুযায়ী, দুই env-এর জন্যই** (6.4; PLAN)। এক route-এর সমস্যা বাকিগুলোর গড়ে ঢাকা পড়ে না, আর `namespace` label বলে কোন env।
- **PodCrashLooping-এ `for` নেই** (6.4; PLAN)। প্রথম restart-এই বাজে, শেষ restart-এর ১০ মিনিট পরে থামে। Q8-এ memory-র সমস্যা (OOMKilled) ধরা পড়ে সবার আগে।
- **NodeDiskFilling শুধু `/`-এর জন্য, `for: 5m`** (6.4; PLAN)। প্রশ্ন সময় বলেনি; ৫ মিনিট একবারের ঝলকে বাজা আটকায়।
- **Slack-এর title-এর link runbook-এ** (6.4; Claude-এর বাছাই)। default link যায় Alertmanager-এর ভেতরের ঠিকানায়, যা Slack থেকে খোলে না।
- **Alert-এর unit test promtool দিয়ে** (6.4; Claude-এর বাছাই)। প্রশ্নের শর্ত ("৫ মিনিট ধরে", "১০ মিনিটে বাড়ছে") lab ছাড়াই যাচাই হয়। Prometheus-এর version kube-prometheus-stack-এর সাথে মেলে (v3.15.1)।
- **load test-এর হার: catalog ১৬/s, order ৬/s** (6.5; PLAN-এর k6 আর "worker-এর ক্ষমতার ৬০–৭০%")। মোট ২২ RPS, Q8-এর "২০ বা তার বেশি"-র ওপরে। সুস্থ অবস্থায় queue ছোট থাকে; worker ধীর হলে queue বাড়ে আর QueueBacklog বাজে।
- **V3 ভিডিও dev-এ, dev-এর values GitHub-এর web editor দিয়ে বদলে** (6.5; Claude-এর বাছাই)। lab machine-এ GitHub-এ push করার credential রাখা হয় না। prod-এর fault Q8-এ peer-এর কাজ।
- **নতুন দুই repo-তে Claude-এর নাম নেই** (user-এর নিয়ম, 17 Nov)।
  - এখন থেকে কোনো commit-এ `Co-Authored-By: Claude` লাইন নেই, আর দুই ফোল্ডারের কোনো ফাইলে Claude-এর নাম নেই।
  - devops-final-এর পুরনো commit যেমন আছে থাকে (user রাজি)।
  - split-এর সময় `publish-repos.sh` পুরনো লাইনগুলো মুছে দেয়।
- **Publish একটা script দিয়ে, হাতে নয়** (Claude-এর বাছাই)। message পরিষ্কারের কাজ প্রতিবার একইভাবে হলে তবেই hash এক থাকে আর push fast-forward হয়; হাতে করলে ভুলের সুযোগ।
- **Q8-এর load একটানা, সুস্থ অবস্থা থেকে recovery পর্যন্ত** (8.1; Claude-এর বাছাই, PLAN-এর ৪০ মিনিটের বদলে ৬০ পর্যন্ত)। প্রশ্নের "১৫ মিনিট, ২০+ RPS" এর ভেতরেই পড়ে; একই load-এ আগে-পরে তুলনা করা যায়, আর recovery dashboard-এ দেখাতে traffic লাগে।
- **Peer-এর access peer-এর commit আর prod-এর sync-এর পরপরই সরানো** (8.1; Claude-এর বাছাই)। প্রশ্নের "এক ঘণ্টা"-র ভেতরে থাকে, আর peer-এর কাজ তখনই শেষ।
- **Revert user-এর নিজের PC থেকে** (8.1)। lab machine-এ push-এর credential নেই; GitHub-এর web editor-এ revert-এর বোতাম নেই, আর হাতে আগের মান লিখতে হলে diff দেখতে হয়। `git revert` prod-এর values ফাইলের সবশেষ commit উল্টায়, খুলে না দেখে।
- **Peer-এর জন্য মানের তালিকা পদ্ধতির ভেতরেই** (8.1; PLAN-এর আলাদা `docs/chaos-menu.md`-এর বদলে, যাতে বাড়তি ফাইল না হয়)। প্রতিটা মান k6-এর load-এ নিজের alert বাজায়: `latencyMs: 1500` (`/products/{id}`-এর ৩০%, p95 প্রায় ২ s), `errorRate: 0.2` (৫%-এর ওপরে), `memoryLeak` (২৫৬Mi-তে কয়েক মিনিটে OOMKilled), `slowDb` (queue ১০ মিনিট ৫০-এর ওপরে)।
- **RCA-র সংখ্যা cluster ভাঙার আগেই** (8.1)। destroy-এর পরে Prometheus-এর data থাকে না।
- **RCA আগে commit, diff-এর সাথে মেলানো পরের commit-এ** (8.1)। Git-এর ইতিহাসই দেখায় RCA diff দেখার আগে লেখা।

## 12. জানা বিষয়

- **Docker 29-এ image-এর size দুইভাবে দেখায়।** PC-01-এ (যেখানে repo আছে `E:\devops-final`-এ) Docker containerd image store ব্যবহার করে। `docker images`-এ দুইটা সংখ্যা আসে:
  - DISK USAGE: unpack করা layer আর compressed blob মিলিয়ে। Q2-তে pip সরানোর পর web 90 MB, API 142 MB, worker 114 MB; আগে API ছিল 159 MB।
  - CONTENT SIZE: compressed image-এর মাপ।

  Unpack করা size (`docker history`-র যোগফল) web 64.6, API 109.2, worker 88.0 MB।
- **Windows-এর curl দেরি একটু কম মাপে।** Docker-এর ভেতরের 0.5 s-এর দেরি curl দেখায় 0.498 s। তাই latency যাচাই হবে server-এর histogram দিয়ে।
- **PC-01-এ port 80 আর 8080 আগে থেকেই ব্যস্ত।** 80 ধরে আছে `httpd` (Apache), 8080 ধরে আছে একটা `php` process। তাই PC-01-এর `.env`-এ `WEB_PORT=127.0.0.1:8088`। Lab-এর পরিষ্কার machine-এ default 80-ই চলবে।
- **PC-01-এর WSL Ubuntu 24.04-এ `make`, `docker` আর `curl` আছে।** Docker Desktop-এর daemon একই, তাই Makefile আসল Linux-এ চালিয়ে দেখা যায়।
- **WSL-এর default shell zsh।** `wsl.exe -- bash -c '...'` দিলে ভেতরের `$(...)` অংশ zsh আগেই, ভুল folder-এ চালিয়ে ফেলে। লম্বা কাজ একটা script ফাইলে লিখে `wsl.exe -d Ubuntu -- bash <file>` দিয়ে চালাও।
- **Claude-এর window লুকানো থাকলে built-in browser-এর screenshot time out হয়।** তখন page-এর লেখা পড়ে আর JavaScript দিয়ে মেপে যাচাই করা হয়।
- **Server-এর কাজ local-এ রিহার্সাল করার উপায় (Q3-এ ব্যবহার হয়েছে, Q4-এর Ansible-এও লাগবে):** systemd সহ Ubuntu 24.04 container, `--privileged` দিয়ে চালানো। UFW-ও এতে চলে। কয়েকটা জিনিস মাথায় রাখতে হয়:
  - Docker CLI আর compose plugin `docker:29-cli` image থেকে copy করতে হয়।
  - Host-এর Docker socket `/docker.sock`-এ mount করতে হয়, আর boot-এর পরে `/run/docker.sock`-এ symlink দিতে হয়, কারণ systemd `/run`-এর mount ঢেকে দেয়।
  - D-Bus নেই, তাই `systemctl status` root হিসেবে চালাতে হয়।
- **Mock provider-এর সীমা।** Provider-এর `default_tags` আসল provider-এর ভেতরে মেশে, তাই mock test দিয়ে প্রমাণ করা যায় না যে tag বসেছে। সেটা দেখা হবে lab-এ, tag দিয়ে resource খুঁজে।
- **Credential ছাড়া `terraform init` (backend সহ) থামে "No valid credential sources found"-এ।** এটা প্রত্যাশিত; test-এর জন্য `init -backend=false` চালাতে হয়।
- **Mock provider AWS-এর default মান বসায় না** (যেমন `map_public_ip_on_launch` থাকে `null`)। যে মান test-এ যাচাই করতে হবে, সেটা code-এ স্পষ্ট করে লিখতে হয়।
- **Resource-গুলোর পরস্পরের যোগ (subnet → VPC, route → gateway) দেখতে test-এ `command = apply` লাগে।** Mock apply AWS ছোঁয় না, শুধু id বানিয়ে দেয়; `plan`-এ id অজানা থাকে।
- **একটা variable-এর validation fail করলে, যে validation সেই variable দেখে, Terraform সেটা আর চালায় না।** তাই এক AZ-এর test-এ শুধু `public_subnet_cidrs`-এর error আশা করা হয়।
- **Windows থেকে mount করা folder world-writable দেখায়, তখন Ansible সেই folder-এর `ansible.cfg` উপেক্ষা করে।** তাই `run.sh` `ANSIBLE_CONFIG` env দিয়ে ফাইলটা স্পষ্ট করে দেয়।
- **UFW বন্ধ থাকা অবস্থায় `ufw` module default policy বদলালে প্রথমবার "changed" দেখায়।** UFW চালু হওয়ার পরের run-এ আর দেখায় না, তাই idempotency-র পরীক্ষা হয় দ্বিতীয় run-এ।
- **Mock হলেও provider ARN-এর আকার যাচাই করে** (যেমন listener-এর `load_balancer_arn`)। তাই test-এ load balancer আর target group-কে `mock_resource` দিয়ে বৈধ আকারের ARN দিতে হয়। প্রতিটা instance-কে আলাদা মান দিতে `override_resource { target = res["key"] }` চলে (Terraform 1.17)।
- **বাসার PC (repo `E:\Personal\devops-final`-এ):**
  - Port 80 ধরে আছে Laravel Herd-এর nginx (user-এর নিজের, ছোঁয়া হয় না)। তাই এখানকার `.env`-এও `WEB_PORT=127.0.0.1:8088`, page http://127.0.0.1:8088।
  - Docker Desktop চলে **cgroup v1**-এ (WSL2 kernel 5.15)।
- **Kubernetes 1.35 থেকে kubelet cgroup v1-এ চলতে অস্বীকার করে।** Error: `kubelet is configured to not run on a host using cgroup v1`। এর সাথে আরেকটা সমস্যা: host-এর cgroup namespace-এ থাকলে container-এর ভেতরের systemd আর kubelet cgroup-এর আলাদা path দেখে (`cgroup ["kubepods"] has some missing paths`)। তাই রিহার্সালে:
  - Node container পায় `--cgroupns=private`। cgroup v2 host-এ এটা Docker-এর default।
  - Host cgroup v1 হলে kubelet পায় `fail-cgroupv1=false`।

  Lab-এর EC2 cgroup v2-তে চলে, সেখানে এর কিছুই লাগে না।
- **containerd-এর overlayfs container-এর নিজের overlay filesystem-এর ওপর চলে না।** তাই রিহার্সালের node-এ `/var/lib/rancher/k3s` আর `/var/lib/kubelet` Docker volume, k3s-এর নিজের image-এর মতো। `docker rm -v` সেগুলোও মোছে।
- **`tests/verify.yml` `ansible/group_vars` নিজে থেকে পড়ে না,** কারণ playbook আর inventory দুটোই `tests/`-এ। তাই `vars_files` দিয়ে একই ফাইল পড়ে।
- **`.gitignore`-এর pattern code-ও লুকাতে পারে।** `kubeconfig*` role-এর folder লুকিয়েছিল, অথচ রিহার্সাল pass করছিল, কারণ রিহার্সাল চলে disk থেকে, Git থেকে নয়। নতুন folder যোগ হলে `git status`-এ সব ফাইল আসছে কিনা দেখতে হয়।
- **বাসার PC-তে GitHub থেকে download ধীর।** k3s binary (~70 MB) তিন node-এ নামতে কয়েক মিনিট লাগে; `get_url`-এর default 10 সেকেন্ডের timeout এতে ভেঙেছিল।
- **Windows-এর `python` (Microsoft Store-এর alias) shell থেকে চালালে আটকে থাকে।** JSON বা অন্য কিছু পড়তে Docker-এর `python:3.12-alpine` ব্যবহার করো।
- **AWS provider প্রায় 150 MB, আর বাসার PC-তে প্রতিটা folder-এর `init` সেটা আবার নামাত।** তাই Docker volume `shoplite-tf-cache`-এ provider-এর cache, `TF_PLUGIN_CACHE_DIR=/cache` দিয়ে (CLAUDE.md-র Terraform command)। একবার ভরলে সব folder-এর `init` সেখান থেকে নেয়।
- **বাসার PC-র network মাঝে মাঝে download মাঝপথে কেটে দেয়** (curl exit 18, partial file)। Ansible-এর download-এ retry আছে; হাতে curl চালালে `--retry 5 --retry-all-errors` দাও।
- **Root folder-এ `terraform console` backend-এর `init` চায়।** Template render করে দেখতে console চালাও `terraform/templates` folder থেকে, যেখানে backend নেই।
- **Claude Code-এর safety check একটা command আটকায়, যদি তাতে `sh -c` script আর `rm` একসাথে থাকে।** Test-এর container মোছার কাজ (`docker rm` নাম ধরে) আলাদা command-এ রাখো।
- **AWS CLI v1 `AWS_REGION` পড়ে না, শুধু `AWS_DEFAULT_REGION`।** v2 দুটোই পড়ে। Lab-এর document দুটোই export করে।
- **Local k3s-এ registry ছাড়াই নিজের image চালানো যায়:** `docker save --platform linux/amd64 ... | docker exec -i <k3s> ctr --namespace k8s.io images import -`। Chart-এ `imagePullPolicy: IfNotPresent` থাকায় k3s নিজের ভেতরের image-ই নেয়।
- **Helm-কে k3s container-এর network-এ চালালে kubeconfig যেমন আছে তেমনই চলে** (`docker run --network container:<k3s>`): `127.0.0.1:6443` তখন k3s-এরই। একই উপায়ে `curl` দিয়ে NodePort-এ যাওয়া যায়, ALB যেমন যায়।
- **Traefik-এর Middleware CRD Traefik বসানোর পরেই আসে।** তাই chart-এর server-side dry run আর install, দুটোই Traefik-এর পরে। Lab-এ ArgoCD-তেও Traefik-কে shoplite-এর আগে sync করতে হবে (Q7)।
- **AWS-এর command lab ছাড়াই অনেকটা যাচাই করা যায়।**
  - `--query`: `jmespath` দিয়ে, API-র আকারের নমুনা data-য়।
  - Argument-এর syntax: credential ছাড়া চালিয়ে। শুধু `Unable to locate credentials`-এ থামলে syntax ঠিক।
  - Script দুটো scratchpad-এ ছিল; দরকার হলে আবার লেখা সহজ।
- **Script-এ `export MSYS_NO_PATHCONV=1` থাকলে Windows-এর `git.exe` `/tmp/...` path বোঝে না** (`fatal: cannot change to '/tmp/...'`)। Docker-এর জন্য এই variable দরকার, তাই git চালাও folder-এ ঢুকে, relative path দিয়ে, অথবা container-এর ভেতরে।
- **Docker Desktop বন্ধ থাকলে** (`failed to connect to the docker API at npipe:////./pipe/dockerDesktopLinuxEngine`) PowerShell থেকে চালু করা যায়: `Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"`। তারপর `docker info` সাড়া দেওয়া পর্যন্ত অপেক্ষা করো (প্রায় এক মিনিট)। Bash-এর background process দিয়ে চালু হয়নি।
- **বাসার PC-তে কিছু একটা %TEMP%-এর খালি folder মুছে দেয়** (15 Nov 02:05:10-এ দেখা)। Git repo-র খালি `refs/` folder চলে গেলে git সেটাকে আর repo মানে না। তাই রিহার্সালের repo container-এর ভেতরে।
- **Traefik-এর প্রথম sync-এর পরে ArgoCD ৩০–৪৫ সেকেন্ড ComparisonError দেখায়:** `unable to resolve parseableType for GroupVersionKind: traefik.io/v1alpha1, Kind=IngressRoute`। ServerSideApply-এর diff নতুন CRD-এর schema চায়, যা ArgoCD-র cache-এ তখনো আসেনি; নিজে থেকেই চলে যায়। ওই সময় app দেখায় "Unknown Healthy", তাই root তখন wave 1-এ চলে যেতে পারে। CRD তখন থাকেই, তাই ক্ষতি নেই; কিন্তু রিহার্সালের wave-এর পরীক্ষা এজন্য Traefik-এর pod-এর বদলে CRD তৈরির সময় দেখে।
- **ArgoCD 3-এ resource-এর health Application-এর CR-এ থাকে না** (`.status.resources[*].health` ফাঁকা)। কোন resource Healthy নয়, দেখতে API লাগে: `/argocd/api/v1/applications/<name>/resource-tree`, admin-এর token দিয়ে (`POST /argocd/api/v1/session`)। অথবা UI।
- **ArgoCD-র page curl দিয়ে চাইলে `<base href="/">` আসে।** `/argocd` base বসে শুধু browser-এর request-এ (`Accept: text/html`)।
- **Module-এর input validation `terraform test`-এর mock apply-তেও চলে**, mock-এর বানানো মান দিয়ে। তাই root-এর test-এ mock করা ECR repo-কে ঠিকঠাক ARN দিতে হয় (`mock_resource "aws_ecr_repository"`), নইলে github-oidc-এর validation সব apply থামিয়ে দেয়।
- **Terraform 1.17.2-এর `plan`/`apply`-এ `-exclude` নেই।** একটা module বাদ দিয়ে apply করতে হলে সেটা comment out করতে হয়।
- **অফিসের network থেকে GitHub-এর REST API token ছাড়া 403 দেয় (rate limit)।** Release-এর tag, commit SHA আর তারিখ git দিয়ে পাওয়া যায়: `git ls-remote --tags`, আর `git fetch --depth=1 <repo> refs/tags/<tag>`।
- **actionlint 1.7.12 নতুন release-এর input চেনে না।** configure-aws-credentials v6.3.0-তে `aws-regoin` বানান ভুল ধরেনি। Pipeline-এর রিহার্সাল তাই pin করা commit-এর `action.yml` থেকে মেলায়।
- **yq-তে `strenv()` string রাখে, `env()` রাখে না।** `strenv()` `0123456`/`1e23456`-কে quote করে লেখে; `env()` YAML-কে type ঠিক করতে দেয়, তখন এগুলো number হয়ে যায়।
- **ঠিকভাবে বন্ধ না হলে PC-01-এ Docker Desktop শুরুতেই crash করে (16 Nov)।**
  - Log (`%LOCALAPPDATA%\Docker\log\host\com.docker.backend.exe.log`) বলে `backend crashed ... remove ...\Docker\run\dockerInference: The file cannot be accessed by the system`। পরের বার একই কথা বলে `docker-secrets-engine\engine.sock` নিয়ে।
  - এগুলো socket ফাইল। Docker, `Remove-Item`, `del` কেউই মুছতে পারে না।
  - সমাধান: যে folder-এ এগুলো আছে (`%LOCALAPPDATA%\Docker\run`, `%LOCALAPPDATA%\docker-secrets-engine`), তার নাম বদলে `*.stale-<তারিখ>` রাখো, তারপর Docker আবার চালু করো। Docker নতুন folder বানায়। পুরনোগুলো PC restart-এর পরে মোছা যায়।
- **Docker-এর ভেতরের k3s-এ node-exporter চালু হয় না, যদি না `/` shared mount হয়।** node-exporter `/` mount করে HostToContainer propagation দিয়ে। আসল node-এ systemd `/`-কে shared রাখে, container-এ সেটা private থাকে। রিহার্সাল তাই k3s চালুর পরে `mount --make-rshared /` চালায়।
- **Grafana sub path-এ (`/grafana`) চললে তার নিজের metrics-ও `/grafana/metrics`-এ চলে যায়।** chart-এর ServiceMonitor `/metrics` পড়ে আর target down দেখায়, তাই path ঠিক করে দিতে হয়েছে।
- **Prometheus-এর image distroless:** ভেতরে shell বা `wget` নেই। Query করতে হয় বাইরে থেকে; রিহার্সাল node-এর network থেকে ClusterIP-তে curl করে।
- **Loki chart 20.2.1 monolithic mode-এ write, read আর backend-এর replica 0 চায়।** এদের default 3, আর `singleBinary.replicas`-এর default 0। দুটো না বদলালে chart render-ই হয় না ("more than zero replicas configured for both the monolithic and simple scalable targets")।
- **Tempo chart 3.2.1-এ Jaeger receiver বাদ দেওয়া যায় না।** Service-এর template `tempo.receivers.jaeger.protocols.*` সরাসরি পড়ে, তাই `jaeger: null` দিলে render ভাঙে। Receiver তাই chart-এর default-এই থাকে।
- **Alloy chart 1.15.0-এ `rbac.rules` বা `rbac.clusterRules` খালি তালিকা (`[]`) হলে ClusterRole-এর YAML ভেঙে যায়।** দুটো একসাথে লেখা হয় বলে খালিটা `[]` হয়ে rule-এর তালিকার মাঝে বসে। তাই দুটোতেই একটা করে rule।
- **Grafana-র provisioning ফাইলে `$` environment variable বোঝায়।** Literal `$` লিখতে হয় `$$` দিয়ে (Grafana-র docs), তাই link-এর URL লেখা `$${__value.raw}`। রিহার্সাল দেখে, Grafana-র API-তে সেটা `${__value.raw}` হয়েই আসে।
- **`loki.source.kubernetes` প্রতিটা container একবারই পড়ে,** যদিও `discovery.kubernetes` container-এর প্রতিটা port-এর জন্য আলাদা target দেয় (যেমন Loki-র নিজের ৩টা port)। রিহার্সালের cluster-এ Alloy-র API (`/api/v0/web/components/loki.source.kubernetes.pods`) দেখিয়েছে ৪৩টা target, প্রতিটা `instance` একবার।
- **Loki 3 নিজে থেকে `service_name` label যোগ করে,** আর Alloy-র `loki.source.kubernetes` যোগ করে `job` আর `instance`। কোনোটাতেই নতুন stream বাড়ে না: মানগুলো আসে আগের label থেকেই, container-প্রতি একটা।
- **PromQL-এ `A * on (pod, container) B` ফলাফলে শুধু `pod` আর `container` রাখে।** বাঁ দিকের বাকি label (যেমন `reason`) রাখতে `group_left` লাগে। Restart-এর table-এ এই ভুল ধরা পড়েছিল শুধু আসল restart ঘটিয়ে দেখায়: ফাঁকা cluster-এ query সফল, কিন্তু ফল ফাঁকা।
- **Windows-এর Docker Desktop mount করা ফোল্ডারের permission মানে না; Linux (GitHub-এর runner, WSL) মানে।**
  - `mktemp -d` ফোল্ডার 0700, তাই অন্য user হিসেবে চলা image (যেমন Prometheus-এর `nobody`) ভেতরের ফাইল পড়তে পারে না।
  - GitHub-এর প্রথম আসল run এতে লাল হয়েছিল। CI-র script push-এর আগে WSL Ubuntu-তে চালিয়ে দেখো: `wsl.exe -d Ubuntu -- bash <file>`।
- **PC-01 থেকে GitHub-এর REST API rate limit (403) দেয়।** Public repo-র Actions page browser-এ পড়া যায়: run → job → ব্যর্থ ধাপের log।

## 13. পরের কাজ

Q1–Q7-এর code শেষ; Q3–Q8-এর lab-এর পদ্ধতিও শেষ (section 4, 5, 6, 6b, 7, 7b)। এরপর:

1. GitHub-এর setting (দুই repo ভাগ 17 Nov হয়ে গেছে): Q5-এর পদ্ধতির section 0.2 (deploy key আর secret `GITOPS_DEPLOY_KEY`) আর 0.3 (Slack-এর incoming webhook), আর Q7-এর পদ্ধতির section 0। Q8-এর জন্য একজন peer আর সময়। এরপর shoplite-app-এর বদল devops-final-এ commit করে `bash publish-repos.sh push`; shoplite-gitops বদলাবে তার নিজের clone-এ বা GitHub-এর web editor-এ।
2. AWS lab-এ চালানো আর প্রমাণ, একটা session-এ: Q4 → Q5 → Q6 → Q7 → Q8, তারপর Q3 (17 Nov-এ user-এর সাথে ঠিক হওয়া ক্রম)।
   - Q4: `docs/evidence/q4/commands.md`।
   - Q5: `docs/evidence/q5/commands.md`।
   - Q6: `docs/evidence/q6/commands.md`, Q5-এর পদ্ধতির section 4-এর পরে, একই session-এ।
   - Q7: `docs/evidence/q7/commands.md`, একই session-এ।
   - Q8: `docs/evidence/q8/commands.md`, একই session-এ। Section 8-এর সংখ্যা destroy-এর আগে।
   - Q3: `linux/evidence/commands.md`, আর সেখানেই Q2-এর পরিষ্কার machine-এর ভিডিও (V1)।
   - পুরো session screen record করা থাকবে; ভিডিও V1–V6 পরে কাটা হবে।
3. Lab-এর পরে: `docs/RCA.md` ভরানো (timeline, screenshot আর section 8-এর সংখ্যা থেকে) আর commit; তারপর peer-এর commit-এর সাথে মেলানো, আলাদা commit-এ; screenshot-গুলো `docs/evidence/qN/`-এ; `bash publish-repos.sh push`।
4. README হয়ে গেছে (`04b7063`, section 7c)। Lab-এর পরে কিছু বদলালে (যেমন bonus) README-র deviation log-ও মেলাতে হবে।
