# PodCrashLooping

| | |
|---|---|
| Severity | critical |
| Fires when | a container's restart count increased in the last 10 minutes (it fires at the first restart and clears 10 minutes after the last one) |
| Labels | `namespace`, `pod`, `container` |
| Rule | `monitoring/alert-rules/shoplite-alerts.yaml` |

## Symptoms

The Slack message names the namespace, pod and container. On the dashboard, the table
**Restarted containers: restarts and last termination reason** lists it.

## Impact

Every restart drops the container's work in progress and leaves fewer pods to serve; a
container that keeps restarting ends in CrashLoopBackOff and does not serve at all.
For order-worker, orders wait in the queue ([QueueBacklog](QueueBacklog.md)); for
catalog-api, requests fail ([HighErrorRate](HighErrorRate.md)); for PostgreSQL or Redis, both.

## First five minutes (Grafana only)

1. Open the dashboard **ShopLite — Golden Signals**, and pick the pod's environment at the
   top (Environment).
2. **Restarted containers**: how many restarts, and the last termination reason:
   - `OOMKilled`: the container went over its memory limit and the kernel killed it;
   - `Error`: the process exited with an error (look for a traceback in its logs);
   - `Completed`: the process stopped by itself.
3. **Memory usage per pod**: a pod that climbs steadily to its limit, drops to near zero
   and climbs again (a sawtooth) grows its memory until it is killed.
4. A purple deploy mark just before the first restart means a change reached the cluster at
   that time.
5. The container's last lines before each restart, in Explore (Loki), around the restart
   time (below).

Queries for Explore:

```promql
kube_pod_container_status_last_terminated_reason{namespace="shoplite"} == 1
```

```promql
increase(kube_pod_container_status_restarts_total{namespace="shoplite"}[10m])
```

```logql
{namespace="shoplite", container="order-worker"}
```

## Likely causes and fixes

- **OOMKilled after a change** (deploy mark): revert that change in Git (shoplite-gitops:
  `git revert <commit>`, push; for prod, ArgoCD `shoplite-prod`: REFRESH, then SYNC).
- **OOMKilled with no change:** the workload needs more memory than its limit. Raise the
  container's memory limit in the chart's values in Git, not with kubectl.
- **Error with a traceback:** a bug or a bad setting; fix it in a new commit, or revert the
  commit that brought it.
- **A dependency is down** (catalog-api's readiness depends on PostgreSQL and Redis): fix
  the dependency first.

## Recovered when

No new restarts for 10 minutes: the alert clears and Slack shows it as RESOLVED. Memory stays
flat on the dashboard.
