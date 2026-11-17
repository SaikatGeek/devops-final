# HighLatency

| | |
|---|---|
| Severity | warning |
| Fires when | the 95th percentile of one route's request latency in catalog-api is above 1 second, for 5 minutes |
| Labels | `namespace` (the environment: `shoplite` is prod, `shoplite-dev` is dev), `route` |
| Rule | `monitoring/alert-rules/shoplite-alerts.yaml` |

## Symptoms

The Slack message names the slow route. On the dashboard, the route's p95 line in
**Request latency per route: p50, p95, p99** is above the red 1 s line.

## Impact

Pages and orders are slow for at least 1 request in 20 on that route. If it grows, clients
time out and the slowness turns into errors ([HighErrorRate](HighErrorRate.md)).

## First five minutes (Grafana only)

1. Open the dashboard **ShopLite — Golden Signals**, and pick the alert's environment at the
   top (Environment).
2. **Request latency per route**: is the median (p50) slow too (every request), or only the
   tail (p95, p99)? Is it one route or all of them? A purple deploy mark just before the
   rise means a change reached the cluster at that time.
3. Click an exemplar (a dot on the latency graph) of the slow route: it opens that request's
   trace in Tempo. See where the time goes:
   - the request span itself is long, but its database and queue spans are short: the time
     is spent in catalog-api itself;
   - a database span (`SELECT products`, `INSERT orders`) is long: PostgreSQL is slow;
   - the queue span (`send orders:pending`) is long: Redis is slow.
4. **CPU usage per pod** and **Requests per second**: more traffic than usual, or a pod at
   its CPU limit?
5. **Recent error logs**: timeouts or other errors at the same time.

Queries for Explore:

```promql
histogram_quantile(0.95, sum by (route, le) (rate(http_request_duration_seconds_bucket{namespace="shoplite"}[5m])))
```

```traceql
{ resource.service.name = "catalog-api" && duration > 1s }
```

## Likely causes and fixes

- **A change was deployed when the latency rose** (deploy mark), and the time is spent in
  catalog-api itself: revert that change in Git (shoplite-gitops: `git revert <commit>`,
  push; for prod, ArgoCD `shoplite-prod`: REFRESH, then SYNC).
- **PostgreSQL is slow** (long database spans): look at PostgreSQL's CPU and memory on the
  dashboard, and at the worker's database spans too: both services share the database.
- **More traffic than catalog-api's pods can serve** (CPU at the limit): raise the replicas or
  the CPU limit in the chart's values in Git, not with kubectl.

## Recovered when

The route's p95 is back under 1 s, and Slack shows the alert as RESOLVED.
