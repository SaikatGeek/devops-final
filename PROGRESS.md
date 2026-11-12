# ShopLite: কাজের অগ্রগতি (progress log)

শেষ আপডেট: 2026-11-12, Step 9-এর পরে (Q1 শেষ)। Deadline: 17 Nov 2026।

প্রতিটা step শেষ হলে এই ফাইল আপডেট হবে। বিস্তারিত পরিকল্পনা [PLAN.md](PLAN.md)-তে, প্রশ্নপত্র [project.md](project.md)-তে।

অন্য PC-তে কাজ চালাতে: [OFFICE-PC-GUIDE.md](OFFICE-PC-GUIDE.md)। Claude-এর কাজের নিয়ম: [CLAUDE.md](CLAUDE.md)।

চিহ্ন: ✅ শেষ ও push হয়েছে · 🟡 আংশিক · ⬜ বাকি

## 1. এক নজরে

| প্রশ্ন | বিষয় | মার্ক | অবস্থা |
|---|---|---|---|
| Q1 | Application | 8 | ✅ ৯টা step-এর সবগুলো শেষ |
| Q2 | Docker | 10 | 🟡 তিনটা Dockerfile শর্ত মেনে তৈরি (web সহ); compose-এ web, smoke test, Makefile আর runtime image থেকে pip সরানো বাকি (section 7) |
| Q3 | Linux server | 5 | ⬜ AWS lab লাগবে |
| Q4 | Terraform, Ansible | 17 | ⬜ AWS lab লাগবে |
| Q5 | Kubernetes, Helm | 15 | ⬜ শুধু `init.sql` chart-এর জায়গায় রাখা আছে |
| Q6 | Observability | 25 | 🟡 app-এর দিক তৈরি (৬টা metric, trace, exemplar, log-এ trace_id); Prometheus, Loki, Tempo, Grafana বসানো বাকি |
| Q7 | CI/CD, GitOps | 10 | ⬜ |
| Q8 | Chaos, RCA | 10 | ⬜ chaos flag-এর code তৈরি (Step 7); exercise আর RCA lab-এ |
| Bonus | EKS, SQS, canary, SLO | +10 | ⬜ |

**মোট কয়টা step:** Q1 ভাঙা হয়েছে ৯টা step-এ (নিচে)। পুরো project-এ ৮টা প্রশ্ন আর ৪টা bonus; PLAN.md অনুযায়ী Q1 আর Q2 চলে নিজের machine-এ, Q3 থেকে বাকিগুলো চলে AWS lab-এর ১০টা session-এ। Q2 শুরু হলে সেটাও এভাবে ছোট step-এ ভাঙা হবে।

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
| 8 | Unit test (কমপক্ষে ৫টা API test) | ✅ প্রতিটা step-এর সাথে লেখা; এখন ৭৭টা (API ৪৮, worker ২৯) | সব commit-এ |
| 9 | web: Nginx + HTML/JS (product তালিকা, order, status) | ✅ image-এর ১৬টা check সহ | `eb46deb` |

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
- Local-এ trace দেখার জন্য Jaeger (`--profile tracing`)। Kubernetes-এ এর জায়গায় Tempo বসবে।

**Step 7: Chaos flag (Q1.5)**
- চারটা flag, সবগুলো default বন্ধ। মান পড়া আর যাচাই হয় `config.py`-তে; ভুল মান দিলে service চালুই হয় না।

| Flag | কোথায় | কী করে | Grafana/trace-এ কীভাবে ধরা পড়বে |
|---|---|---|---|
| `CHAOS_LATENCY_MS` | catalog-api, `app/faults.py` | ~30% `GET /products/{id}`-এ ওই কয় ms দেরি, DB query-র আগে | p95 লাফ দেয়; trace-এ server span লম্বা, DB span ছোট, শুরুতে ফাঁক |
| `CHAOS_ERROR_RATE` | catalog-api, `app/faults.py` | ওই ভাগ `POST /orders`-এ 500, DB ছোঁয়ার আগেই | 5xx বাড়ে; ERROR log; trace-এ একটাই span, INSERT নেই |
| `CHAOS_MEMORY_LEAK` | order-worker, `processor.py` | প্রতি processed order-এ 1 MiB ধরে রাখে, কখনো ছাড়ে না | worker-এর memory সোজা উপরে ওঠে, শেষে OOMKilled আর restart |
| `CHAOS_SLOW_DB` | order-worker, `store.py` | প্রতিটা UPDATE-এর আগে `SELECT pg_sleep(2)` | queue জমে; `order_processing_seconds` বাড়ে; trace-এ 2 s-এর `SELECT` span |

- Log, error-এর body বা span-এর নামে কোথাও flag-এর নাম বা মান নেই। দুই service-এর test-এ এটা যাচাই করা আছে।
- যাচাই, Jaeger সহ আসল stack-এ:
  - Latency 500 ms: server-এর histogram অনুযায়ী ৪৪০টার মধ্যে ১৩৪টা (৩০.৫%) 0.5 s-এর বেশি। Trace-এ DB span শুরু হয় +500.9 ms-এ, চলে 0.8 ms।
  - Error rate 0.3: ১০০টা order-এ ২৫টা 500, DB-তে ঠিক ৭৫টা নতুন row। ব্যর্থ trace-এ শুধু 0.4 ms-এর একটা ERROR span। ২৫টা ERROR log, প্রতিটায় `trace_id`।
  - Slow DB: order শেষ হয় 5.4 s-এ (স্বাভাবিক 1.2–2.1 s)। Trace-এ প্রতিটা UPDATE-এর আগে ~2000 ms-এর `SELECT pg_sleep(2)`। ৪২টা order-ই 5–7.5 s-এর bucket-এ।
  - Memory leak: ৪০টা order-এ worker-এর RSS 50.0 থেকে 90.9 MiB (প্রতি order-এ ~1.02 MiB)।
  - সব flag বন্ধ করলে আবার স্বাভাবিক: order 1.8–2.1 s, RSS 48 MiB। সব log মিলিয়ে "chaos" শব্দ একবারও নেই।

**Step 9: web**
- `services/web/`: Nginx-এর উপর একটা static page (`public/`)। Product-এর তালিকা দেখায়, order নেয়, প্রতি সেকেন্ডে status দেখে যতক্ষণ না `COMPLETED` বা `FAILED` হয়। ID দিয়ে order খোঁজা যায়, আর API-র error (404, 500) বার্তা হিসেবে দেখায়।
- Page-এর সব call যায় `/api/...`-তে। Nginx সেটা catalog-api-তে পাঠায়, `/api` অংশ বাদ দিয়ে, query রেখে।
- Image: `nginxinc/nginx-unprivileged:1.30.6-alpine`, uid 101, port 8080, `HEALTHCHECK`, unpack করা size 64.6 MB। Stage তিনটা: `builder` page-এ version বসায়, `test` চালায় ১৬টা check, `runtime` আসল image।
- Log প্রতি লাইনে JSON, অন্য দুই service-এর মতো একই পাঁচটা field (`trace_id` null, কারণ nginx-এ trace নেই)। 5xx হলে ERROR, 4xx হলে WARNING; `/healthz` log হয় না।
- যাচাই:
  - Test stage-এ ১৬টা check pass। ইচ্ছা করে ভুল upstream দিলে proxy-র check FAIL করে, exit 1।
  - Web-কে compose-এর network-এ চালিয়ে browser থেকে: ১২টা product, order #145 আর #146 1.2–1.7 s-এ `COMPLETED`, ID দিয়ে খোঁজা কাজ করে, না-থাকা order-এ 404-এর বার্তা।
  - `CHAOS_ERROR_RATE=1` দিলে page দেখায় "Could not place the order (HTTP 500: internal server error)"। JavaScript-এর কোনো error নেই।
  - ফোনের মাপে (375 px) page পাশে scroll করে না; Stock column লুকিয়ে যায়।
  - Upstream-এর নাম না মিললেও nginx healthy থাকে, page 200, `/api` 502।
  - ১৪টা access log লাইনের সবগুলো বৈধ JSON। CPU limit 1 দিলে worker process ১টা।

## 3. Commit-এর তালিকা

| Commit | তারিখ | কী |
|---|---|---|
| `04ad552` | 2026-11-12 | Data services আর catalog-api core (Step 1, 2) |
| `fd89722` | 2026-11-12 | Orders API (Step 3) |
| `3ede8c1` | 2026-11-12 | order-worker (Step 4) |
| `225269e` | 2026-11-12 | ৬টা metric (Step 5) |
| `2a33e9c` | 2026-11-12 | Tracing (Step 6) |
| `161c225` | 2026-11-12 | ৪টা chaos flag (Step 7) |
| `eb46deb` | 2026-11-12 | web: page, Nginx, Dockerfile (Step 9) |

সব commit GitHub-এর `main`-এ push করা আছে।

## 4. কোথায় কী আছে

```text
devops-final/
├── PLAN.md, project.md, PROGRESS.md      পরিকল্পনা, প্রশ্নপত্র, এই log
├── shoplite-app/
│   ├── docker-compose.yml                postgres, redis, catalog-api, order-worker (+ jaeger, ঐচ্ছিক)
│   ├── .env.example                      local-এর setting; আসল .env Git-এ যায় না
│   ├── helm/shoplite/files/init.sql      table আর seed (Compose আর Kubernetes দুটোই এটা ব্যবহার করে)
│   └── services/
│       ├── web/
│       │   ├── public/                   index.html, app.js, style.css: page
│       │   ├── nginx/default.conf.template  /api proxy, no-cache, /healthz, JSON log
│       │   ├── tests/                    image-এর ১৬টা check, fake API
│       │   └── Dockerfile                builder → test → runtime
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

## 5. Local-এ চালানো আর দেখা

`shoplite-app` folder থেকে চালাও:

```bash
cp .env.example .env
docker compose up -d --build
```

Trace সহ চালাতে `.env`-এ `OTEL_EXPORTER_OTLP_ENDPOINT=http://jaeger:4318` লাইনটা চালু করো, তারপর:

```bash
docker compose --profile tracing up -d --build
```

| কী দেখবে | কোথায় |
|---|---|
| API-র সব endpoint, নিজে চালিয়ে দেখা | http://127.0.0.1:8000/docs |
| API-র metric | http://127.0.0.1:8000/metrics |
| Trace (Jaeger) | http://127.0.0.1:16686 → Service `order-worker` → Find Traces |
| Log | `docker compose logs -f catalog-api order-worker` |

একটা chaos flag চালু করে দেখতে (যেমন slow DB):

```bash
CHAOS_SLOW_DB=true docker compose up -d --wait
```

বন্ধ করতে flag ছাড়া আবার `docker compose up -d --wait`। অথবা `.env`-এ লাইন বসাও; `.env.example`-এ চারটাই লেখা আছে।

Unit test (service-এর folder থেকে, যেমন `services/catalog-api`):

```bash
docker build --target test -t test-image . && docker run --rm test-image
```

`services/web`-এও একই command; সেখানে test মানে image-এর ১৬টা check।

Web এখনো compose-এ নেই (Q2-তে যোগ হবে)। তার আগে page দেখতে চাইলে, stack চালু থাকা অবস্থায় `shoplite-app` থেকে:

```bash
docker build --target runtime -t shoplite/web:local services/web && docker run -d --rm --name shoplite-web-check --network shoplite_default -p 127.0.0.1:8088:8080 shoplite/web:local
```

তারপর http://127.0.0.1:8088 খোলো। কাজ শেষে `docker stop shoplite-web-check`; চালু থাকলে `docker compose down` network মুছতে পারে না।

## 6. পথে নেওয়া সিদ্ধান্ত (demo আর README-র deviation log-এ লাগবে)

- **Worker product-এর stock কমায় না।** কমালে Q8-এর ১৫ মিনিটের load test-এ stock শেষ হয়ে সব order `FAILED` হতো, আর তদন্ত গুলিয়ে যেত।
- **Probe আর scrape request HTTP metric আর trace-এ গোনা হয় না।** `/healthz`, `/readyz`, `/metrics` কয়েক সেকেন্ড পরপর আসে, এগুলো আসল traffic চাপা দিত।
- **`/readyz`-এর 503 log হয় WARNING হিসেবে, ERROR না।** তাই Q8-এ ERROR log মানে আসল application error।
- **Queue depth Redis থেকে scrape-এর মুহূর্তে পড়া হয়।** Redis-এ না পৌঁছালে মান `NaN`, পুরনো সংখ্যা দেখায় না।
- **DB span নিজে লেখা, auto-instrumentation না।** Auto-instrumentation `/readyz`-এর প্রতিটা `SELECT 1`-এর জন্য আলাদা trace বানাত।
- **`init.sql` রাখা Helm chart-এর ভেতরে**, যাতে Compose আর Kubernetes একই ফাইল ব্যবহার করে।
- **Test-এ `httpx`-এর বদলে `httpx2`।** Starlette 1.x এটাই চায়।
- **Local trace viewer Jaeger 2.23.0।** Production-এ Tempo + Grafana। Jaeger 2.23-এ API path `/api/v3`।
- **Chaos flag-এর নাম কোথাও ছাপা হয় না।** Log, 500-এর body বা span-এর নাম, কোথাও না; Q8-এ কারণ বের করতে হবে লক্ষণ দেখে। যে comment-এ flag-এর নাম আছে, সেটা চলমান code-এর লাইনের পাশে না রেখে আলাদা লাইনে রাখা হয়েছে, কারণ exception হলে traceback ওই লাইনটা ছাপায়। ব্যতিক্রম শুধু ভুল মান: তখন service চালু হওয়ার সময়ই থেমে যায়, error-এ variable-এর নাম থাকে।
- **Latency-র নিজের কোনো span নেই।** Trace-এ সেটা DB span-এর আগের ফাঁক হিসেবে দেখা যায়, আসল কোনো bug-এর মতো।
- **Memory leak-এ non-zero byte।** শূন্য দিয়ে ভরা memory Linux অনেক সময় সত্যিই খরচ করে না, তখন pod-এর memory বাড়ত না।
- **Random source বাইরে থেকে দেওয়া যায়** (`FaultInjector`-এর `rng` আর `sleep`)। তাই test-এ ঠিক করে দেওয়া যায় কোন request-এ দেরি বা error হবে।
- **কাজের ক্রম (12 Nov):** আগে অ্যাপ পুরো শেষ (Step 9, Q2), তারপর Terraform, Ansible, Helm, monitoring আর CI। ওগুলোর code এই PC-তেই লেখা হবে; lab-এ শুধু চালানো আর প্রমাণ নেওয়া।
- **Web চলে uid 101-এ, বাকি দুইটা 10001-এ।** 101 হলো `nginx-unprivileged` image-এর নিজের non-root user; বদলালে nginx-এর লেখার folder-গুলোর permission নতুন করে ঠিক করতে হতো।
- **Web-এর config container চালু হওয়ার সময় তৈরি হয়।** Image-এর entrypoint template থেকে `API_UPSTREAM` আর DNS server বসায়। `proxy_pass`-এ variable থাকায় nginx নাম খোঁজে প্রতি request-এ, তাই catalog-api না থাকলেও চালু হয়। Kubernetes-এ `API_UPSTREAM`-এ পুরো নাম দিতে হবে (`catalog-api.<namespace>.svc.cluster.local:8000`), কারণ nginx-এর resolver search domain মানে না। Kubernetes-এ অবশ্য `/api` সরাসরি Traefik থেকে catalog-api-তে যাবে (PLAN Phase 6)।
- **Page-এর সব ফাইলে `Cache-Control: no-cache`, আর heading নেয় `<title>`-এর লেখা।** Q7-এ শুধু `<title>` বদলালে tab আর page দুই জায়গাতেই নতুন নাম দেখা যাবে, reload-এই।
- **Footer-এ build-এর version।** `docker build --build-arg VERSION=<short SHA>` দিলে page-এ দেখা যায় কোন commit চলছে (Q7-এ CI দেবে); local-এ `dev`।
- **Worker process-এর সংখ্যা CPU limit অনুযায়ী** (`NGINX_ENTRYPOINT_WORKER_PROCESSES_AUTOTUNE`)। `auto` দিলে nginx পুরো machine-এর CPU গুনে এই PC-তে ২৮–৩২টা process চালু করত।

## 7. জানা বিষয়

- **Docker 29-এ image-এর size দুইভাবে দেখায়।** এই PC-তে Docker containerd image store ব্যবহার করে। `docker images`-এ DISK USAGE (API 159 MB, worker 132 MB) মানে unpack করা layer আর compressed blob মিলিয়ে; CONTENT SIZE (36.6 MB, 30.4 MB) মানে compressed। আসল unpack করা size API 122.6 MB, worker 101.4 MB, দুটোই শর্তের ভেতরে। তবু grader যাতে 159 দেখে ভুল না বোঝে, Q2-তে runtime venv থেকে pip (13 MB) সরানো হবে; তাতে DISK USAGE-ও 150 MB-এর নিচে নামবে।
- **Windows-এর curl দেরি একটু কম মাপে।** Docker-এর ভেতরের 0.5 s-এর দেরি curl দেখায় 0.498 s। তাই latency যাচাই হবে server-এর histogram দিয়ে।
- **এই PC-তে port 80 আর 8080 আগে থেকেই ব্যস্ত।** 80 ধরে আছে `httpd` (Apache), 8080 ধরে আছে একটা `php` process। Q2-তে web-এর default port 80-ই থাকবে (lab-এর পরিষ্কার machine-এ ফাঁকা); এই PC-তে `.env`-এ `WEB_PORT=8088` দিতে হবে।
- **Claude-এর window লুকানো থাকলে built-in browser-এর screenshot time out হয়।** তখন page-এর লেখা পড়ে আর JavaScript দিয়ে মেপে যাচাই করা হয়।

## 8. পরের কাজ

1. **Q2:** web-কে compose-এ যোগ (শুধু web বাইরে খোলা, `${WEB_PORT:-80}:8080`, catalog-api healthy হলে তবে চালু), `scripts/smoke-test.sh`, `Makefile` (`build up down test smoke`), runtime image থেকে pip সরানো। Checkpoint: পরিষ্কার Linux machine-এ `make up && make smoke`।
2. তারপর infra-র code, এই PC-তেই: Q3-এর Linux ফাইল, Q4-এর Terraform module আর Ansible role, Q5-এর Helm chart, Q6-এর dashboard, alert আর runbook, Q7-এর workflow।
3. তারপর AWS lab-এ চালানো আর প্রমাণ: Q3 → Q4 → Q5 → Q6 → Q7 → Q8 (PLAN.md section 4)।

**সময়:** PLAN.md অনুযায়ী আজ (12 Nov) প্রথম lab session S1 হওয়ার কথা ছিল; Q1 শেষ, Q2 চলছে, তাই প্রায় এক দিন পিছিয়ে। পিছিয়ে পড়লে PLAN-এর নিয়মে আগে S9 (EKS), তারপর S8 বাদ যাবে।
