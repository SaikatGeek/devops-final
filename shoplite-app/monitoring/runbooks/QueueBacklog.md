# QueueBacklog

| | |
|---|---|
| Severity | warning |
| Fires when | more than 50 orders wait in the Redis queue `orders:pending`, for 10 minutes |
| Labels | `namespace` (the environment: `shoplite` is prod, `shoplite-dev` is dev) |
| Rule | `monitoring/alert-rules/shoplite-alerts.yaml` |

## Symptoms

The Slack message gives the number of waiting orders. On the dashboard, **Order queue depth**
is above its red line at 50 and does not come down.

## Impact

New orders are stored, but stay PENDING longer than usual: customers wait for their
confirmation. Nothing is lost while the queue only grows; the orders are processed once
order-worker catches up.

## First five minutes (Grafana only)

1. Open the dashboard **ShopLite — Golden Signals**, and pick the alert's environment at the
   top (Environment).
2. **Orders created vs processed**: are more orders created than processed? Are processed
   orders `completed`, or `failed`?
3. **Worker replicas**: at 4, the most the HorizontalPodAutoscaler allows, the workers are
   all busy. If fewer are available than the HPA wants, pods do not start or keep
   restarting: see **Restarted containers**.
4. Is each order slow to process? Query the processing time (below). In Explore, search Tempo
   for order-worker's traces and open a slow one: a long `UPDATE orders` span means the
   database is slow; a long `simulate work` span is the work itself.
5. **Memory usage per pod** and **CPU usage per pod** of order-worker, and the worker's error
   lines (below). A purple deploy mark just before the rise means a change reached the
   cluster at that time.

Queries for Explore:

```promql
histogram_quantile(0.95, sum by (le) (rate(order_processing_seconds_bucket{namespace="shoplite"}[5m])))
```

```logql
{namespace="shoplite", service="order-worker", level=~"ERROR|WARNING"}
```

```traceql
{ resource.service.name = "order-worker" && duration > 3s }
```

## Likely causes and fixes

- **Processing is slow** (long database spans in the worker's traces): the database is the
  bottleneck. If it began with a deploy mark, revert that change in Git (shoplite-gitops:
  `git revert <commit>`, push; for prod, ArgoCD `shoplite-prod`: REFRESH, then SYNC).
- **The workers keep restarting** (Restarted containers, OOMKilled): see
  [PodCrashLooping](PodCrashLooping.md).
- **A burst of orders larger than 4 workers can handle**, with normal processing times: the
  queue drains on its own when the burst ends. If such bursts are normal, raise the HPA's
  maximum in the chart's values in Git.

## Recovered when

The queue depth is back under 50 and falling, processed keeps up with created, and Slack
shows the alert as RESOLVED.
