# ShopLite: কাজের অগ্রগতি (progress log)

শেষ আপডেট: 2026-11-12, Q2-এর পরে। Deadline: 17 Nov 2026।

প্রতিটা step শেষ হলে এই ফাইল আপডেট হবে। বিস্তারিত পরিকল্পনা [PLAN.md](PLAN.md)-তে, প্রশ্নপত্র [project.md](project.md)-তে।

অন্য PC-তে কাজ চালাতে: [OFFICE-PC-GUIDE.md](OFFICE-PC-GUIDE.md)। Claude-এর কাজের নিয়ম: [CLAUDE.md](CLAUDE.md)।

**মূল নিয়ম (12 Nov):** প্রশ্নে যা চাওয়া, শুধু সেটুকুই বানানো হবে। সুবিধার জন্য বাড়তি tool বা feature যোগ হবে না। সময় লাগলেও কোনো কিছু কাটছাঁট করা হবে না।

চিহ্ন: ✅ শেষ ও push হয়েছে · 🟡 আংশিক · ⬜ বাকি

## 1. এক নজরে

| প্রশ্ন | বিষয় | মার্ক | অবস্থা |
|---|---|---|---|
| Q1 | Application | 8 | ✅ ৯টা step-এর সবগুলো শেষ |
| Q2 | Docker | 10 | ✅ চারটা অংশই শেষ; নতুন clone-এ `make up && make smoke` pass করেছে (WSL Ubuntu)। Lab-এর নতুন EC2-তে প্রমাণ (ভিডিও V1) বাকি |
| Q3 | Linux server | 5 | ⬜ পরের কাজ: `linux/` ফাইল নিজের PC-তে লেখা; চালানো আর প্রমাণ lab-এর EC2-তে |
| Q4 | Terraform, Ansible | 17 | ⬜ code নিজের PC-তে, চালানো lab-এ |
| Q5 | Kubernetes, Helm | 15 | ⬜ শুধু `init.sql` chart-এর জায়গায় রাখা আছে |
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

## 4. Commit-এর তালিকা

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

সব commit GitHub-এর `main`-এ push করা আছে।

## 5. কোথায় কী আছে

```text
devops-final/
├── PLAN.md, project.md, PROGRESS.md      পরিকল্পনা, প্রশ্নপত্র, এই log
├── shoplite-app/
│   ├── docker-compose.yml                ৫টা component: web, catalog-api, order-worker, postgres, redis
│   ├── Makefile                          build, up, down, test, smoke
│   ├── scripts/smoke-test.sh             stack চালু → readyz → order → COMPLETED
│   ├── .env.example                      local-এর setting (WEB_PORT সহ); আসল .env Git-এ যায় না
│   ├── helm/shoplite/files/init.sql      table আর seed (Compose আর Kubernetes দুটোই এটা ব্যবহার করে)
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

## 6. Local-এ চালানো আর দেখা

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

## 7. পথে নেওয়া সিদ্ধান্ত (demo আর README-র deviation log-এ লাগবে)

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

## 8. জানা বিষয়

- **Docker 29-এ image-এর size দুইভাবে দেখায়।** PC-01-এ (যেখানে repo আছে `E:\devops-final`-এ) Docker containerd image store ব্যবহার করে। `docker images`-এ দুইটা সংখ্যা আসে:
  - DISK USAGE: unpack করা layer আর compressed blob মিলিয়ে। Q2-তে pip সরানোর পর web 90 MB, API 142 MB, worker 114 MB; আগে API ছিল 159 MB।
  - CONTENT SIZE: compressed image-এর মাপ।

  Unpack করা size (`docker history`-র যোগফল) web 64.6, API 109.2, worker 88.0 MB।
- **Windows-এর curl দেরি একটু কম মাপে।** Docker-এর ভেতরের 0.5 s-এর দেরি curl দেখায় 0.498 s। তাই latency যাচাই হবে server-এর histogram দিয়ে।
- **PC-01-এ port 80 আর 8080 আগে থেকেই ব্যস্ত।** 80 ধরে আছে `httpd` (Apache), 8080 ধরে আছে একটা `php` process। তাই PC-01-এর `.env`-এ `WEB_PORT=127.0.0.1:8088`। Lab-এর পরিষ্কার machine-এ default 80-ই চলবে।
- **PC-01-এর WSL Ubuntu 24.04-এ `make`, `docker` আর `curl` আছে।** Docker Desktop-এর daemon একই, তাই Makefile আসল Linux-এ চালিয়ে দেখা যায়।
- **WSL-এর default shell zsh।** `wsl.exe -- bash -c '...'` দিলে ভেতরের `$(...)` অংশ zsh আগেই, ভুল folder-এ চালিয়ে ফেলে। লম্বা কাজ একটা script ফাইলে লিখে `wsl.exe -d Ubuntu -- bash <file>` দিয়ে চালাও।
- **Claude-এর window লুকানো থাকলে built-in browser-এর screenshot time out হয়।** তখন page-এর লেখা পড়ে আর JavaScript দিয়ে মেপে যাচাই করা হয়।

## 9. পরের কাজ

1. **Q3-এর code**, `linux/` folder-এ, নিজের PC-তে লেখা হবে (project.md 3.1–3.4, PLAN Phase 4):
   - `sshd_config`: root আর password দিয়ে login বন্ধ।
   - `deploy` user আর `ops` group বানানোর command।
   - `/var/log/shoplite/`-এর permission: `chown`, `chmod`, আর ঠিক একটা `setfacl`।
   - `systemd/`: `shoplite-backup.service` (`Restart=on-failure`) আর `.timer`; প্রতি রাতে `pg_dump` যাবে `/var/backups/shoplite/`-এ।
   - `firewall/`: UFW, default deny, শুধু 22, 80, 443 খোলা।

   চালানো আর screenshot হবে lab-এর Ubuntu EC2-তে। Q2-এর পরিষ্কার machine-এর প্রমাণও (ভিডিও V1) সেখানেই নেওয়া হবে।
2. তারপর Q4-এর Terraform module আর Ansible role, Q5-এর Helm chart, Q6-এর dashboard, alert আর runbook, Q7-এর workflow, সবই নিজের PC-তে।
3. তারপর AWS lab-এ চালানো আর প্রমাণ: Q3 → Q4 → Q5 → Q6 → Q7 → Q8 (PLAN.md section 4)।
