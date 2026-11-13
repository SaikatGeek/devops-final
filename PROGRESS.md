# ShopLite: কাজের অগ্রগতি (progress log)

শেষ আপডেট: 2026-11-14, Q5 step 5.3-এর পরে (বাসার PC)। Deadline: 17 Nov 2026।

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
| Q5 | Kubernetes, Helm | 15 | 🟡 Code শেষ (5.1–5.3): chart-এ পাঁচটা workload, non-root, requests আর limits, Secret আর ConfigMap, PDB, HPA, Ingress, NetworkPolicy; Traefik ALB-র পেছনে (NodePort, `/ping`); local k3s-এ dev আর prod দুটোই চলে, order `COMPLETED`। বাকি 5.4 (lab-এর পদ্ধতি) আর lab-এ চালানো |
| Q6 | Observability | 25 | 🟡 app-এর দিক তৈরি (৬টা metric, trace, exemplar, log-এ trace_id); Prometheus, Loki, Tempo, Grafana বসানো বাকি |
| Q7 | CI/CD, GitOps | 10 | ⬜ |
| Q8 | Chaos, RCA | 10 | ⬜ chaos flag-এর code তৈরি (Step 7); exercise আর RCA lab-এ |
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
  - এই PC-র Docker-এর cgroup v1 (section 11)।
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
| 5.4 | Lab-এ চালানোর পদ্ধতি (`docs/evidence/q5/commands.md`), checkpoint | সব | ⬜ পরের কাজ |

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

## 7. Commit-এর তালিকা

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

সব commit GitHub-এর `main`-এ push করা আছে।

## 8. কোথায় কী আছে

```text
devops-final/
├── PLAN.md, project.md, PROGRESS.md      পরিকল্পনা, প্রশ্নপত্র, এই log
├── shoplite-app/
│   ├── docker-compose.yml                ৫টা component: web, catalog-api, order-worker, postgres, redis
│   ├── Makefile                          build, up, down, test, smoke
│   ├── scripts/smoke-test.sh             stack চালু → readyz → order → COMPLETED
│   ├── .env.example                      local-এর setting (WEB_PORT সহ); আসল .env Git-এ যায় না
│   ├── helm/shoplite/                    Q5-এর chart: Chart.yaml, values.yaml, values-dev.yaml, values-prod.yaml
│   │   ├── files/init.sql                table আর seed (Compose আর Kubernetes দুটোই এটা ব্যবহার করে)
│   │   └── templates/                    web, catalog-api (+ PDB), order-worker (+ HPA), postgres, redis, ingress, networkpolicy, configmap, _helpers
│   ├── helm/tests/run.sh                 chart-এর রিহার্সাল: local k3s-এ install, যাচাই, শেষে সব মোছে
│   ├── docs/evidence/q4/commands.md      Q4 lab-এ চালানোর পদ্ধতি, প্রমাণ আর screenshot-এর তালিকা (screenshot-ও এখানে)
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
│   │   ├── outputs.tf                    VPC আর subnet-এর id, node-এর instance id, app-এর URL, ECR-এর URL, Ansible-এর inventory, kubectl-এর tunnel
│   │   ├── templates/inventory.ini.tftpl lab-এর inventory: node instance id দিয়ে, SSH SSM-এর ভেতর দিয়ে
│   │   ├── modules/network/              VPC, subnet, IGW, NAT, route table (+ নিজের tests/)
│   │   ├── modules/compute/              node-এর security group, IAM role, key pair, ৩টা EC2 (+ নিজের tests/)
│   │   ├── modules/alb/                  ALB, listener, target group, ALB → node-এর rule (+ নিজের tests/)
│   │   ├── modules/ecr/                  তিনটা image repository (+ নিজের tests/)
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
└── shoplite-gitops/                      এখন শুধু README; কাজ Q5, Q7-এ
```

## 9. Local-এ চালানো আর দেখা

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

Ansible-এর রিহার্সাল (Docker আর internet লাগে; ৩টা node-এ hardening আর k3s, দুইবার run, যাচাই, শেষে সব মোছে; ৫–১০ মিনিট), `shoplite-app` থেকে:

```bash
bash ansible/tests/run.sh
```

## 10. পথে নেওয়া সিদ্ধান্ত (demo আর README-র deviation log-এ লাগবে)

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
- **NetworkPolicy শুধু Postgres আর Redis-এ, শুধু আসা traffic-এ** (প্রশ্ন এটুকুই চায়)। "সবকিছু বন্ধ, তারপর একটা একটা খোলা" ধরনের default-deny বা বের হওয়া traffic-এর নিয়ম নেই।
- **অনুমতি শুধু একই namespace-এর pod-কে** (`namespaceSelector` নেই)। তাই dev আর prod একই cluster-এ থাকলেও একে অপরের database-এ পৌঁছাতে পারে না।
- **ECR-এর credential আসে kubelet-এর credential provider থেকে, pull secret থেকে নয়।** ECR-এর token ১২ ঘণ্টায় শেষ হয়, তাই secret বারবার বদলাতে হতো। Plugin প্রতিবার node-এর role দিয়ে নতুন token নেয়, আর কিছু কোথাও জমা থাকে না।
- **`k3s_kubelet_args` lab-এ ফাঁকা।** শুধু রিহার্সাল এতে `fail-cgroupv1=false` দেয়, যখন Docker host cgroup v1-এ চলে।

## 11. জানা বিষয়

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

## 12. পরের কাজ

Q5-এর 5.1 আর 5.2 শেষ (section 6)। এরপর:

Q5-এর code শেষ (5.1–5.3, section 6)। এরপর:

1. **Q5 step 5.4: lab-এ Q5 চালানোর পদ্ধতি** (`docs/evidence/q5/commands.md`)। শুরুর আগে user-কে একটা সিদ্ধান্ত নিতে হবে: lab-এ image ECR-এ যাবে কীভাবে, আর chart বসাবে কে।
   - **(ক) PLAN-এর পথ:** আগে "GitOps-এর ভিত" (PLAN Phase 6)।
     - shoplite-gitops-এর কাঠামো: root app, dev আর prod-এর Application, `envs/*/values.yaml`।
     - cluster-এর bootstrap: namespace, Secret, ArgoCD।
     - pipeline-এর প্রথম সংস্করণ: build → OIDC দিয়ে ECR-এ push → gitops-এ tag commit।

     তারপর 5.4-এর পদ্ধতি ArgoCD দিয়েই। এগুলো Q7-এর অংশ, শুধু আগে বানানো হবে। PLAN বলে cluster প্রতি session-এ নতুন হয়, তাই প্রথম দিন থেকেই সব Git থেকে আসা ভালো।
   - **(খ) এখনই 5.4, হাতে:** lab-এর machine থেকে `docker build` আর ECR-এ push, তারপর `helm install`। পরে Q7-এ ArgoCD-তে বদল। Lab-এর machine-এ Docker লাগবে, আর একই কাজ দুইবার হবে।
   - দুই পথেই থাকবে: namespace আর Secret, প্রমাণ (pod, HPA, PDB-র drain, NetworkPolicy), আর checkpoint (ALB-র URL-এ browser থেকে order `COMPLETED`, ভিডিও V2)।
2. তারপর Q6-এর dashboard, alert আর runbook, আর Q7-এর বাকি অংশ, সবই নিজের PC-তে।
3. তারপর AWS lab-এ চালানো আর প্রমাণ: Q3 → Q4 → Q5 → Q6 → Q7 → Q8 (PLAN.md section 4)।
   - Q3: `linux/evidence/commands.md`, আর সেখানেই Q2-এর পরিষ্কার machine-এর ভিডিও (V1)।
   - Q4: `docs/evidence/q4/commands.md`।
