# Question 6: commands and evidence

The observability stack runs in the namespace `monitoring`. ArgoCD installs all of it from
`shoplite-gitops`:

- `kube-prometheus-stack`: Prometheus, Alertmanager, Grafana, node-exporter, kube-state-metrics;
- `loki`, `tempo` and `alloy`;
- `monitoring-config`: the dashboard and the alerts.

Their settings are in this repository:

- `monitoring/stack/` for the charts;
- `monitoring/dashboards/` for the dashboard;
- `monitoring/alert-rules/` for the alerts;
- `monitoring/runbooks/` for the runbooks.

Most of the evidence is taken in Grafana, in the browser. The few terminal commands run in the
**lab terminal**, from the `shoplite-app` folder of the clone. The screenshots for each part
are listed at its end; the files go in this folder.

> **Cost:** this builds on questions 4 and 5, in the same session. End it with
> [After the session](#after-the-session).

**Before you start:** question 5's procedure ([`../q5/commands.md`](../q5/commands.md)) up to
its section 4, in this session. By then:

- the cluster is bootstrapped, with the Slack webhook of its section 0.3;
- prod is synced;
- `ALB` and `KUBECONFIG` are set in the terminal.

Roughly: 45–60 minutes, most of it with the load test running.

## 0. k6, the load generator

The lab machine is new in every session. Install k6 there, and check its checksum:

```bash
curl -fsSL --retry 5 --retry-all-errors -o ~/tools/k6.tar.gz https://github.com/grafana/k6/releases/download/v1.8.2/k6-v1.8.2-linux-amd64.tar.gz
echo "$(curl -fsSL --retry 5 https://github.com/grafana/k6/releases/download/v1.8.2/k6-v1.8.2-checksums.txt | grep ' k6-v1.8.2-linux-amd64.tar.gz$' | cut -d' ' -f1)  $HOME/tools/k6.tar.gz" | sha256sum --check
tar -xzf ~/tools/k6.tar.gz -C ~/tools k6-v1.8.2-linux-amd64/k6 && sudo install ~/tools/k6-v1.8.2-linux-amd64/k6 /usr/local/bin/
k6 version
```

## 1. Grafana

Grafana is at `/grafana/` on the ALB's port 80. User `admin`; the password exists only in the
cluster:

```bash
echo "Grafana: $ALB/grafana/"
kubectl -n monitoring get secret grafana-admin -o jsonpath='{.data.admin-password}' | base64 -d; echo
```

## 2. 6a: the stack

```bash
kubectl -n argocd get applications
kubectl -n monitoring get pods -o wide
```

Every Application is `Synced` and `Healthy`, and every pod `Running`. There is one Alloy pod
on each of the three nodes.

In Grafana, go to **Connections → Data sources**. There are four: Prometheus, Loki, Tempo
and Alertmanager.

In Grafana, go to **Explore**, pick Prometheus, and run this query in the Table view:

```promql
count by (job, namespace) (up == 1)
```

The table lists node-exporter, kube-state-metrics, and catalog-api and order-worker in both
`shoplite` and `shoplite-dev`. This query must return nothing:

```promql
up == 0
```

Screenshots:
- `01-monitoring-pods.png`: the Applications and the pods of `monitoring`.
- `02-datasources.png`: the four data sources.
- `03-targets-up.png`: the `up` table.

## 3. 6b: the six application metrics

catalog-api and order-worker are scraped through ServiceMonitors:

```bash
kubectl get servicemonitors -n shoplite
kubectl get servicemonitors -n shoplite-dev
```

In Grafana → Explore → Prometheus, run:

```promql
count by (__name__) ({namespace="shoplite", __name__=~"http_requests_total|http_request_duration_seconds_bucket|orders_created_total|orders_processed_total|order_queue_depth|order_processing_seconds_bucket"})
```

It returns six rows, one per metric. The two histograms show as their `_bucket` series.

Screenshots:
- `04-servicemonitors.png`: the ServiceMonitors.
- `05-six-metrics.png`: the six rows.

## 4. Load

In a second terminal, from `shoplite-app`, send prod 22 requests a second for 20 minutes. Set
`ALB` there again, as in question 5's section 1. Leave it running for sections 5 to 7.

```bash
k6 run -e BASE_URL="$ALB" -e DURATION=20m scripts/loadtest.js
```

`scripts/loadtest.js` sends two kinds of traffic:

- 16 catalog requests a second: half list the products, half open one;
- 6 orders a second.

The rates are fixed even when ShopLite slows down.

## 5. 6c: the Golden Signals dashboard under load

After about five minutes of load, open Grafana → **Dashboards → ShopLite — Golden Signals**:

- Environment `shoplite`;
- last 30 minutes.

Every panel has data:

- requests per second, about 22 in total;
- the 5xx rate at 0;
- p50, p95 and p99 per route, well under the red 1 s line;
- the queue near 0;
- orders created vs processed, close together;
- worker replicas going up from 1 as the HPA scales;
- CPU and memory per pod.

The dashboard is a file in Git, loaded by Grafana's sidecar from a ConfigMap:

```bash
kubectl -n monitoring get configmap shoplite-dashboards --show-labels
```

Screenshots:
- `06-dashboard-load.png`: the whole dashboard under load (zoom the browser out so that every
  panel fits).
- `07-dashboard-configmap.png`: the ConfigMap with its label `grafana_dashboard=1`.

## 6. 6d: one order, from its log to its trace and back

1. **Log → trace.** In Grafana → Explore, pick Loki and run:

   ```logql
   {namespace="shoplite", service="catalog-api"} | json | message="order created"
   ```

   Open one line. Its `trace_id` has a **View trace** link (the Loki data source's derived
   field). Click it: the trace opens in Tempo next to the logs.
2. **The whole order in one trace.** The trace has two services:
   - catalog-api: `POST /orders` → `INSERT orders` → `send orders:pending`;
   - order-worker: `process orders:pending` → `UPDATE orders` → `simulate work` →
     `UPDATE orders`.

   The worker's `process orders:pending` is a child of the API's `send orders:pending`: the
   trace context went through the Redis queue inside the message.
3. **Trace → logs.** Open a span of order-worker and click **Logs for this span**. Loki shows
   the worker's lines of this trace (`order processing started`, `order completed`).
4. **Exemplar → trace.** On the dashboard's **Request latency per route** panel, the dots are
   exemplars. Hover one and click **View trace** (or **Query with Tempo**): the trace of that
   very request opens.

Screenshots:
- `08-log-to-trace.png`: the log line with its View trace link.
- `09-order-trace.png`: the order's trace, API → queue → worker → database, spans expanded.
- `10-trace-to-logs.png`: the worker's lines found from the trace.
- `11-exemplar.png`: an exemplar's tooltip on the latency panel.
- `12-exemplar-trace.png`: the trace it opened.

## 7. 6e: alerts and runbooks

1. Grafana → **Alerting → Alert rules**, the data source-managed rules of Prometheus. The
   group `shoplite` has five rules:

   | Alert | Severity |
   |---|---|
   | HighErrorRate | critical |
   | HighLatency | warning |
   | QueueBacklog | warning |
   | PodCrashLooping | critical |
   | NodeDiskFilling | warning |

   Open one: its labels have `severity`, and its annotations have `runbook_url`, a link to
   `monitoring/runbooks/<alert>.md` in this repository.
2. **A test alert to Slack.** Stop dev's worker process once. Kubernetes restarts the
   container, and PodCrashLooping fires:

   ```bash
   kubectl -n shoplite-dev exec deploy/order-worker -- kill 1
   ```

   Within about two minutes the Slack channel gets
   `[FIRING] PodCrashLooping (critical) in shoplite-dev`, with the runbook's link. Ten
   minutes later it gets the RESOLVED message.

Screenshots:
- `13-alert-rules.png`: the five rules.
- `14-alert-labels.png`: one rule opened, with `severity` and `runbook_url`.
- `15-slack-alert.png`: the alert in Slack.
- `16-slack-resolved.png`: the RESOLVED message.

## 8. Video V3: from an alert to the failing request, in under two minutes

This shows the question's goal on dev: a reviewer goes from an alert to the request that
failed, in Grafana alone. It breaks dev on purpose, through Git, and repairs it the same way.

1. Stop the load of section 4 (Ctrl+C), and load dev instead, for 20 minutes:

   ```bash
   k6 run -e BASE_URL="$ALB:8080" -e DURATION=20m scripts/loadtest.js
   ```

2. Make 20% of dev's orders fail with question 1's fault-injection setting. Change dev's
   values in shoplite-gitops in the browser: the lab machine has no right to push. In GitHub,
   open **shoplite-gitops** → `envs/dev/values.yaml` → Edit, add these lines at the end, and
   commit to `main` ("dev: try the error alert"):

   ```yaml
   config:
     chaos:
       errorRate: 0.2
   ```

   ArgoCD syncs dev on its own, within a minute: catalog-api's pods roll with the new
   setting.

3. About five minutes later, HighErrorRate fires for dev, and Slack gets
   `[FIRING] HighErrorRate (critical) in shoplite-dev`. **Start recording** at the Slack
   message, then:
   1. open the runbook from the message;
   2. on the dashboard, choose Environment `shoplite-dev`. **HTTP 5xx error rate** shows
      `/orders` failing, and a purple mark shows when the change arrived;
   3. in **Recent error logs**, open a failed order's line (`request completed`, route
      `/orders`, status 500), then **View trace**;
   4. the trace shows the failed `POST /orders` span, with its error status and no database
      or queue span behind it.

   Stop recording: from the alert to the failing request, under two minutes.
4. Repair dev through Git: in GitHub, edit `envs/dev/values.yaml` again, delete the three
   lines, and commit ("dev: back to normal"). (From a clone that can push, `git revert`
   of step 2's commit does the same.) Let the load run until the 5xx rate is back at 0 and
   Slack shows RESOLVED: about 10 minutes after the commit, because the alert looks at the
   last 5 minutes and Alertmanager sends its updates every 5 minutes.

Video `V3-alert-to-request.mp4`, and screenshot `17-dev-recovered.png`: the dashboard after
the revert, the 5xx rate back at 0.

## After the session

End the session as question 5's procedure does: `LAB_ACTIVE=false`, then question 4's
destroy.
