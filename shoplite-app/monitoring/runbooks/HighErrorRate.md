# HighErrorRate

| | |
|---|---|
| Severity | critical |
| Fires when | more than 5% of one route's requests to catalog-api answer with a 5xx status, for 5 minutes |
| Labels | `namespace` (the environment: `shoplite` is prod, `shoplite-dev` is dev), `route` |
| Rule | `monitoring/alert-rules/shoplite-alerts.yaml` |

## Symptoms

The Slack message names the route and the share of failed requests. On the dashboard, the
**HTTP 5xx error rate** panel is above its red 5% line for that route.

## Impact

Customers get errors on that route: the catalog does not load, or orders are refused. Orders
that failed before they were stored are lost; the customer has to try again.

## First five minutes (Grafana only)

1. Open the dashboard **ShopLite — Golden Signals**, and pick the alert's environment at the
   top (Environment).
2. **HTTP 5xx error rate**: which routes fail, and since when. A purple deploy mark just
   before the rise means a change reached the cluster at that time.
3. **Requests per second**: did the traffic change, or only the errors?
4. **Restarted containers**, **CPU usage per pod**, **Memory usage per pod**: is a pod of
   catalog-api, PostgreSQL or Redis failing?
5. **Recent error logs**: catalog-api's failed requests (`request completed` with a 5xx
   status, `unhandled error`, `enqueue failed`). Open a line and follow its `trace_id`
   (**View trace**).
6. In the trace (Tempo), find the span with the error:
   - only the request span (`POST /orders`, `GET /products`, ...) and no database or queue
     span failing: catalog-api itself answered 5xx;
   - a database span (`SELECT products`, `INSERT orders`): PostgreSQL;
   - the queue span (`send orders:pending`): Redis.

Queries for Explore:

```promql
sum by (route, status) (rate(http_requests_total{namespace="shoplite", status=~"5.."}[5m]))
```

```logql
{namespace="shoplite", service="catalog-api", level="ERROR"}
```

## Likely causes and fixes

- **A change was deployed when the errors began** (deploy mark), and no dependency fails.
  Revert that change in Git: in shoplite-gitops, `git revert <commit>` and push. Then let
  ArgoCD sync: dev syncs on its own; for prod, in ArgoCD open `shoplite-prod`, then
  REFRESH, then SYNC. Fix forward afterwards, in a new commit.
- **PostgreSQL or Redis is down or restarting:** see the database's or Redis's pod on the
  dashboard and the [PodCrashLooping](PodCrashLooping.md) runbook. catalog-api's readiness
  (`/readyz`) fails too, so Kubernetes stops sending it traffic.
- **catalog-api's pods are overloaded** (CPU at its limit): see
  [HighLatency](HighLatency.md).

## Recovered when

The route's 5xx share is back under 5% on the dashboard, and Slack shows the alert as
RESOLVED.
