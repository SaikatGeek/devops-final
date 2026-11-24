# Question 8: commands and evidence

One of question 1.5's fault-injection settings is turned on in prod, through Git, with an
innocuous commit message. You find the fault with the observability tools alone, recover by
reverting the commit, and then write the RCA ([`../../RCA.md`](../../RCA.md)).

The question has "a peer or the instructor" turn the fault on. The instructor asked for the
exercise to be run alone (24 Nov), so [`scripts/chaos-pick.sh`](../../../scripts/chaos-pick.sh)
plays the peer: it turns one of the four faults on, chosen at random, and never shows which.
The investigation starts as blind as with a peer.

**The rules, from the start until the RCA is written:**

- no look at the change: no `git show` or `git diff` of shoplite-gitops, no commit page on
  GitHub, no APP DIFF and no resource in ArgoCD;
- no look at the pods' settings: no `kubectl describe`, `kubectl get configmap` or `env` in
  a pod;
- the investigation uses Grafana only, with its Prometheus, Loki and Tempo data sources, plus
  the Slack alerts and the runbooks they link. No kubectl.

**Times:** every time in this exercise is UTC+6: what Grafana (it follows the browser),
Slack and the computer's clock show. Keep the clock visible in every screenshot.

The commands run in the **lab terminal**, from the `shoplite-app` folder of the clone, except
section 6's, which run on your own PC. The screenshots go in this folder; their names are at
the end of each section.

> **Cost:** this builds on questions 4 to 6, in the same session. End it with
> [After the session](#after-the-session).

**Before you start:**

- this session has gone through question 5's procedure ([`../q5/commands.md`](../q5/commands.md))
  up to its section 4, and question 6's section 0 (k6). So prod is synced, the Slack alerts
  work, and `ALB` and `KUBECONFIG` are set in the terminal;
- your own PC can push to shoplite-gitops (Git Bash; Git asks you to sign in to GitHub the
  first time) and has the shoplite-app repository, for `scripts/chaos-pick.sh` (section 4)
  and the revert (section 6);
- push nothing to shoplite-app and run no workflow until section 7 is done.

Roughly 80 minutes in the lab. The RCA is written afterwards, from the evidence kept here.

## 1. The timeline

Every step below ends with a `mark`: one line with the time, in `~/q8-timeline.txt`. The file
is the timeline of the RCA.

```bash
mark() { printf '%s  %s\n' "$(TZ='<+06>-6' date '+%Y-%m-%d %H:%M:%S %Z')" "$*" | tee -a ~/q8-timeline.txt; }
mark "Q8 started"
```

A new terminal needs the `mark()` line again; the file stays.

## 2. 8.1 step 1: who turns the fault on

The question's step 1 gives a peer write access to shoplite-gitops for an hour. Without a peer
(see the top), nobody else gets access: `scripts/chaos-pick.sh` makes the peer's commit from
your PC, which can push already. It:

- turns exactly one of the four settings in [The four faults](#the-four-faults) on, chosen at
  random, in `envs/prod/values.yaml`;
- commits it with GitHub's own default message, `Update values.yaml`, and pushes it to main;
- prints only the commit's short hash, never the setting;
- stops and changes nothing unless all four are off.

`scripts/tests/pipeline.sh` checks it against copies of shoplite-gitops: in 40 runs each turns
exactly one fault on, in one line, and never names it, and all four turn up.

## 3. A healthy start, under load

1. In a second terminal, from `shoplite-app`, set `ALB` again (question 5's section 1, step
   3) and start the load test:

   ```bash
   k6 run -e BASE_URL="$ALB" -e DURATION=60m scripts/loadtest.js
   ```

   It sends 22 requests a second (16 catalog requests and 6 orders) for up to an hour. One
   run covers the healthy start, the question's 15 minutes at 20 or more requests a second
   under the fault, the investigation and the recovery. It is stopped in section 7. If it
   ends before that, start it again.

   ```bash
   mark "load test started: 22 requests a second"
   ```

2. Start the screen recording (video V6), and keep it running until section 7.
3. After about five minutes, open Grafana → **Dashboards → ShopLite — Golden Signals**, with
   Environment `shoplite` and the last 30 minutes. It looks healthy:
   - the 5xx rate is at 0;
   - every latency is under the red 1 s line;
   - the queue is near 0;
   - no container has restarted.

   ```bash
   mark "baseline: healthy under load"
   ```

Screenshot `01-baseline.png`: the whole dashboard (zoom the browser out so that every panel
fits).

## 4. 8.1 step 2: one fault on, blind

1. On your PC, in Git Bash, from your home folder (it clones shoplite-gitops into
   `q8-gitops`, which section 6 uses again):

   ```bash
   cd ~
   bash <your shoplite-app folder>/scripts/chaos-pick.sh
   ```

   It prints `One fault is on in prod: commit <hash> is on shoplite-gitops main.` and
   nothing about which. Do not open that commit. In the lab terminal:

   ```bash
   mark "one fault pushed to prod, blind: <the hash>"
   ```

2. Sync prod without looking at the change. In ArgoCD (`$ALB/argocd/`): Applications →
   `shoplite-prod` → REFRESH → SYNC → SYNCHRONIZE. Do not open APP DIFF or any resource.
   Wait for `Synced` and `Healthy`:

   ```bash
   mark "prod synced: the fault's commit"
   ```

Screenshots:
- `02-fault-pushed.png`: your PC's terminal with the script's output: the hash, not the
  change.
- `03-prod-synced.png`: shoplite-prod `Synced` and `Healthy`. The summary shows the commit's
  message, not its change.

## 5. 8.1 steps 4 and 5: the investigation, in Grafana only

Keep the load running. The first alert comes within about 15 minutes of the sync, because
most rules wait 5 or 10 minutes before they fire. If none comes, start from the dashboard
(step 3): the fault shows there all the same.

At each step, write down what you saw with `mark`, for example
`mark "dashboard: <what changed, and since when>"`.

1. **Detection.** Slack gets the first `[FIRING]` message: the alert, its environment and,
   for the request alerts, the route.

   ```bash
   mark "first alert: <alert> <labels>"
   ```

   In Grafana → **Alerting → Alert rules**, open that rule. Its expression, threshold and
   `for` time say why it fired.
2. **The runbook.** Open the link in the Slack message, and follow its "First five minutes".
   Every step there uses Grafana only.
3. **Dashboard.** Environment `shoplite`, the last hour:
   - which golden signal moved, on which route or pod, and since when;
   - the purple Deploys mark at the time of the sync;
   - what did not change: the traffic, the other routes, the other pods.
4. **Logs.** In **Recent error logs**, or in Explore → Loki with the runbook's queries, find
   the lines of the affected service from that time, and open one.
5. **Trace.** Open one affected request's trace: from the log line (**View trace**), from an
   exemplar on the latency panel, or in Explore → Tempo with the runbook's TraceQL. Find the
   span that holds the error or the time.
6. **Root cause.** Once the dashboard, the logs and the trace agree, write the root cause in
   one line: which component behaves how, since when, and which change brought it.

   ```bash
   mark "root cause: <one line>"
   cat ~/q8-timeline.txt
   ```

Screenshots (with the clock):
- `04-first-alert.png`: the first alert in Slack.
- `05-alert-rule.png`: the rule in Grafana, with its expression and state.
- `06-dashboard-fault.png`: the dashboard with the fault and the Deploys mark.
- `07-logs.png`: the log lines, one of them opened.
- `08-trace.png`: the trace, with the span that holds the error or the time.
- `09-root-cause.png`: the timeline up to the root cause.

## 6. 8.1 step 6: recover through Git

The revert is pushed from a computer that can push to shoplite-gitops: your own PC (Git asks
you to sign in to GitHub the first time). The lab machine has no right to push.

On your PC, in Git Bash, in the clone that section 4 made:

```bash
cd ~/q8-gitops
git pull -q --ff-only
git log -3 --format='%h  %an  %ad  %s' --date=iso -- envs/prod/values.yaml
```

The newest line is the fault's commit: the hash section 4 printed, and the innocuous message.
Revert it without opening it, and push:

```bash
git revert --no-edit "$(git log -1 --format=%H -- envs/prod/values.yaml)"
git push origin HEAD:main
git log -2 --format='%h  %an  %s'
```

The newest commit is now `Revert "Update values.yaml"`, by you. Then, in the lab terminal:

```bash
mark "revert pushed: <its short hash>"
```

In ArgoCD: `shoplite-prod` → REFRESH → SYNC → SYNCHRONIZE, and wait for `Synced` and
`Healthy`:

```bash
mark "prod synced: the revert"
```

Screenshots:
- `10-revert.png`: the terminal with the revert pushed and the last two commits.
- `11-prod-synced-revert.png`: shoplite-prod `Synced` and `Healthy` on the revert.

## 7. 8.2(c): the recovery on the dashboard

Keep the load running. The pods roll with the old setting, and a second purple mark shows
it. The signal that moved goes back to where it was in section 3 within about 10 minutes,
because the rates and quantiles look at the last 5 minutes. A queue that grew drains more
slowly: its falling line is the recovery.

1. When the dashboard looks like section 3 again:

   ```bash
   mark "dashboard back to normal"
   ```

2. Slack gets the alert's `[RESOLVED]` message:

   ```bash
   mark "RESOLVED in Slack"
   ```

3. Stop the load test (Ctrl+C) and the recording. k6's summary shows `http_reqs` at about 22
   a second, over the question's 20.

Screenshots:
- `12-dashboard-recovered.png`: the whole incident on the dashboard (the last hour): the
  healthy start, the first mark, the fault, the second mark, the recovery.
- `13-slack-resolved.png`: the RESOLVED message.
- `14-k6-summary.png`: k6's summary.

Video `V6-chaos-day.mp4`: sections 3 to 7.

## 8. The numbers for the RCA, before the session ends

Prometheus loses its data when the cluster is destroyed, so take the RCA's numbers now. In
Grafana → Explore → Prometheus:

- pick **Options → Type: Instant**;
- set the time range from the first prod sync to the recovery, as absolute times;
- replace `45m` in the queries with the length of that range.

```promql
sum by (route) (increase(http_requests_total{namespace="shoplite", status=~"5.."}[45m]))
```

```promql
sum by (route) (increase(http_requests_total{namespace="shoplite"}[45m]))
```

```promql
sum(increase(orders_created_total{namespace="shoplite"}[45m]))
```

```promql
sum by (result) (increase(orders_processed_total{namespace="shoplite"}[45m]))
```

```promql
max_over_time(histogram_quantile(0.95, sum by (route, le) (rate(http_request_duration_seconds_bucket{namespace="shoplite"}[5m])))[45m:1m])
```

```promql
max_over_time(max(order_queue_depth{namespace="shoplite"})[45m:1m])
```

```promql
sum by (pod, container) (increase(kube_pod_container_status_restarts_total{namespace="shoplite"}[45m]))
```

In order, they give:

1. the failed requests per route;
2. all the requests per route;
3. the orders created;
4. the orders processed, by result;
5. the worst p95 latency per route;
6. the longest queue;
7. the restarts per container.

A query that returns nothing found none.

Then copy the timeline out of the lab machine, for the RCA:

```bash
cat ~/q8-timeline.txt
```

Screenshots:
- `15-impact.png`: the queries' results (several files if needed: `16a-...`, `16b-...`).
- `16-timeline.png`: the whole timeline.

## 9. 8.2(b): the RCA, and only then the change

1. Write [`docs/RCA.md`](../../RCA.md) from the timeline, the screenshots and the numbers,
   then commit it. Its commit time shows that it was written before the change was read.
2. Now read the fault's commit, the one the revert names. On your PC:

   ```bash
   cd ~/q8-gitops
   git log -1 --grep='^Revert' --format='%s%n%b'
   git show <the hash after "This reverts commit">
   ```

3. Compare the change with the RCA's root cause. Add the result to the RCA's last section,
   in a second commit.

## After the session

End the session as question 5's procedure does: `LAB_ACTIVE=false`, then question 4's
destroy.

## The four faults

What `scripts/chaos-pick.sh` chooses from, at random: one line under `config:` and `chaos:` in
shoplite-gitops' `envs/prod/values.yaml`, set to one of question 1.5's settings.

| Line | Turned on |
|---|---|
| `latencyMs: 0` | `latencyMs: 1500` |
| `errorRate: 0` | `errorRate: 0.2` |
| `memoryLeak: false` | `memoryLeak: true` |
| `slowDb: false` | `slowDb: true` |

Nothing else changes: not the `image:` lines, not the indentation. The commit message is
GitHub's own default, `Update values.yaml`, which names no setting.
