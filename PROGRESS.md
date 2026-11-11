# ShopLite: কাজের অগ্রগতি (progress log)

শেষ আপডেট: 2026-11-12, Step 6-এর পরে। Deadline: 17 Nov 2026।

প্রতিটা step শেষ হলে এই ফাইল আপডেট হবে। বিস্তারিত পরিকল্পনা [PLAN.md](PLAN.md)-তে, প্রশ্নপত্র [project.md](project.md)-তে।

অন্য PC-তে কাজ চালাতে: [OFFICE-PC-GUIDE.md](OFFICE-PC-GUIDE.md)। Claude-এর কাজের নিয়ম: [CLAUDE.md](CLAUDE.md)।

চিহ্ন: ✅ শেষ ও push হয়েছে · 🟡 আংশিক · ⬜ বাকি

## 1. এক নজরে

| প্রশ্ন | বিষয় | মার্ক | অবস্থা |
|---|---|---|---|
| Q1 | Application | 8 | 🟡 ৯টা step-এর ৭টা শেষ (Step 8 কাজের সাথে সাথেই হয়ে গেছে); বাকি Step 7 আর 9 |
| Q2 | Docker | 10 | 🟡 API আর worker-এর Dockerfile শর্ত মেনে তৈরি; web-এর Dockerfile, smoke test, Makefile বাকি |
| Q3 | Linux server | 5 | ⬜ AWS lab লাগবে |
| Q4 | Terraform, Ansible | 17 | ⬜ AWS lab লাগবে |
| Q5 | Kubernetes, Helm | 15 | ⬜ শুধু `init.sql` chart-এর জায়গায় রাখা আছে |
| Q6 | Observability | 25 | 🟡 app-এর দিক তৈরি (৬টা metric, trace, exemplar, log-এ trace_id); Prometheus, Loki, Tempo, Grafana বসানো বাকি |
| Q7 | CI/CD, GitOps | 10 | ⬜ |
| Q8 | Chaos, RCA | 10 | ⬜ chaos flag-এর code Step 7-এ |
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
| 7 | ৪টা chaos flag | ⬜ পরের কাজ | |
| 8 | Unit test (কমপক্ষে ৫টা API test) | ✅ প্রতিটা step-এর সাথে লেখা; এখন ৪৪টা (API ৩১, worker ১৩) | সব commit-এ |
| 9 | web: Nginx + HTML/JS (product তালিকা, order, status) | ⬜ | |

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

## 3. Commit-এর তালিকা

| Commit | তারিখ | কী |
|---|---|---|
| `04ad552` | 2026-11-12 | Data services আর catalog-api core (Step 1, 2) |
| `fd89722` | 2026-11-12 | Orders API (Step 3) |
| `3ede8c1` | 2026-11-12 | order-worker (Step 4) |
| `225269e` | 2026-11-12 | ৬টা metric (Step 5) |
| `2a33e9c` | 2026-11-12 | Tracing (Step 6) |

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
│       ├── catalog-api/app/
│       │   ├── main.py                   সব endpoint
│       │   ├── db.py                     Postgres query আর DB span
│       │   ├── order_queue.py            Redis queue, traceparent সহ message
│       │   ├── middleware.py             প্রতি request-এ log আর HTTP metric
│       │   ├── metrics.py                ৪টা metric
│       │   ├── tracing.py                OpenTelemetry setup
│       │   ├── logging_setup.py          JSON log
│       │   └── config.py                 env থেকে config
│       └── order-worker/worker/
│           ├── main.py                   consumer loop, SIGTERM
│           ├── processor.py              একটা order process করা, consumer span
│           ├── store.py                  status update আর DB span
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

Unit test (service-এর folder থেকে, যেমন `services/catalog-api`):

```bash
docker build --target test -t test-image . && docker run --rm test-image
```

## 6. পথে নেওয়া সিদ্ধান্ত (demo আর README-র deviation log-এ লাগবে)

- **Worker product-এর stock কমায় না।** কমালে Q8-এর ১৫ মিনিটের load test-এ stock শেষ হয়ে সব order `FAILED` হতো, আর তদন্ত গুলিয়ে যেত।
- **Probe আর scrape request HTTP metric আর trace-এ গোনা হয় না।** `/healthz`, `/readyz`, `/metrics` কয়েক সেকেন্ড পরপর আসে, এগুলো আসল traffic চাপা দিত।
- **`/readyz`-এর 503 log হয় WARNING হিসেবে, ERROR না।** তাই Q8-এ ERROR log মানে আসল application error।
- **Queue depth Redis থেকে scrape-এর মুহূর্তে পড়া হয়।** Redis-এ না পৌঁছালে মান `NaN`, পুরনো সংখ্যা দেখায় না।
- **DB span নিজে লেখা, auto-instrumentation না।** Auto-instrumentation `/readyz`-এর প্রতিটা `SELECT 1`-এর জন্য আলাদা trace বানাত।
- **`init.sql` রাখা Helm chart-এর ভেতরে**, যাতে Compose আর Kubernetes একই ফাইল ব্যবহার করে।
- **Test-এ `httpx`-এর বদলে `httpx2`।** Starlette 1.x এটাই চায়।
- **Local trace viewer Jaeger 2.23.0।** Production-এ Tempo + Grafana। Jaeger 2.23-এ API path `/api/v3`।

## 7. পরের কাজ

1. **Step 7:** ৪টা chaos flag (`CHAOS_LATENCY_MS`, `CHAOS_ERROR_RATE`, `CHAOS_MEMORY_LEAK`, `CHAOS_SLOW_DB`), default বন্ধ, test সহ।
2. **Step 9:** web frontend (Nginx unprivileged, port 8080), `/api` proxy করবে catalog-api-তে।
3. **Q2:** web-এর Dockerfile, পুরো compose (৫টা component), `scripts/smoke-test.sh`, `Makefile` (`build up down test smoke`)।
4. তারপর AWS lab: Q3 → Q4 → Q5 → Q6 → Q7 → Q8 (PLAN.md section 4)।

**সময়:** PLAN.md অনুযায়ী Q1 আর Q2 শেষ হওয়ার কথা ছিল 11 Nov-এ, তাই প্রায় এক দিন পিছিয়ে আছি। Q1-এর বাকি দুইটা step আর Q2 শেষ হলে lab-এর কাজ শুরু।
