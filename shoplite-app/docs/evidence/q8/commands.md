# Question 8: commands and evidence

A peer turns one of question 1.5's fault-injection settings on in prod, through Git, with an
innocuous commit message. You find the fault with the observability tools alone, recover by
reverting the commit, and then write the RCA ([`../../RCA.md`](../../RCA.md)).

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
- a peer with a GitHub account is free for about 15 minutes at an agreed time, and has the
  link to [The peer's part](#the-peers-part);
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

## 2. 8.1 step 1: write access for the peer

1. **shoplite-gitops** → Settings → Collaborators → Add people → the peer's GitHub user
   name → Add. On a personal repository a collaborator can push. The peer accepts the
   invitation ([The peer's part](#the-peers-part), step 1).
2. When the peer is listed as a collaborator:

   ```bash
   mark "peer has write access to shoplite-gitops"
   ```

The access ends in section 4, right after the peer's commit: well within the hour the
question allows.

Screenshot `01-peer-access.png`: the peer in the collaborator list.

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

Screenshot `02-baseline.png`: the whole dashboard (zoom the browser out so that every panel
fits).

## 4. 8.1 step 2: the peer turns one fault on

1. Tell the peer to go ([The peer's part](#the-peers-part), steps 2 to 5), and wait for
   "done":

   ```bash
   mark "peer: done"
   ```

2. Sync prod without looking at the change. In ArgoCD (`$ALB/argocd/`): Applications →
   `shoplite-prod` → REFRESH → SYNC → SYNCHRONIZE. Do not open APP DIFF or any resource.
   Wait for `Synced` and `Healthy`:

   ```bash
   mark "prod synced: the peer's commit"
   ```

3. Remove the peer's access: **shoplite-gitops** → Settings → Collaborators → the peer →
   Remove.

   ```bash
   mark "peer's access removed"
   ```

Screenshots:
- `03-prod-synced.png`: shoplite-prod `Synced` and `Healthy`. The summary shows the commit's
  message, not its change.
- `04-peer-removed.png`: the collaborator list without the peer.

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
- `05-first-alert.png`: the first alert in Slack.
- `06-alert-rule.png`: the rule in Grafana, with its expression and state.
- `07-dashboard-fault.png`: the dashboard with the fault and the Deploys mark.
- `08-logs.png`: the log lines, one of them opened.
- `09-trace.png`: the trace, with the span that holds the error or the time.
- `10-root-cause.png`: the timeline up to the root cause.

## 6. 8.1 step 6: recover through Git

The revert is pushed from a computer that can push to shoplite-gitops: your own PC (Git asks
you to sign in to GitHub the first time). The lab machine has no right to push.

On your PC, in Git Bash:

```bash
git clone https://github.com/SaikatGeek/shoplite-gitops.git q8-gitops
cd q8-gitops
git log -3 --format='%h  %an  %ad  %s' --date=iso -- envs/prod/values.yaml
```

The newest line is the peer's commit: their name and the innocuous message. Revert it without
opening it, and push:

```bash
git revert --no-edit "$(git log -1 --format=%H -- envs/prod/values.yaml)"
git push origin HEAD:main
git log -2 --format='%h  %an  %s'
```

The newest commit is now `Revert "<the peer's message>"`, by you. Then, in the lab terminal:

```bash
mark "revert pushed: <its short hash>"
```

In ArgoCD: `shoplite-prod` → REFRESH → SYNC → SYNCHRONIZE, and wait for `Synced` and
`Healthy`:

```bash
mark "prod synced: the revert"
```

Screenshots:
- `11-revert.png`: the terminal with the revert pushed and the last two commits.
- `12-prod-synced-revert.png`: shoplite-prod `Synced` and `Healthy` on the revert.

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
- `13-dashboard-recovered.png`: the whole incident on the dashboard (the last hour): the
  healthy start, the first mark, the fault, the second mark, the recovery.
- `14-slack-resolved.png`: the RESOLVED message.
- `15-k6-summary.png`: k6's summary.

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
- `16-impact.png`: the queries' results (several files if needed: `16a-...`, `16b-...`).
- `17-timeline.png`: the whole timeline.

## 9. 8.2(b): the RCA, and only then the change

1. Write [`docs/RCA.md`](../../RCA.md) from the timeline, the screenshots and the numbers,
   then commit it. Its commit time shows that it was written before the change was read.
2. Now read the peer's commit, the one the revert names. On your PC:

   ```bash
   cd q8-gitops
   git log -1 --grep='^Revert' --format='%s%n%b'
   git show <the hash after "This reverts commit">
   ```

3. Compare the change with the RCA's root cause. Add the result to the RCA's last section,
   in a second commit.

## After the session

End the session as question 5's procedure does: `LAB_ACTIVE=false`, then question 4's
destroy.

## The peer's part

For the peer. The student sends this link.

1. Accept the invitation to `SaikatGeek/shoplite-gitops`: from the e-mail, or at
   https://github.com/SaikatGeek/shoplite-gitops/invitations.
2. When the student says "go", open
   https://github.com/SaikatGeek/shoplite-gitops/blob/main/envs/prod/values.yaml and click
   Edit (the pencil).
3. Under `config:` and `chaos:`, change exactly one line, to one of these:

   | Line | Change it to |
   |---|---|
   | `latencyMs: 0` | `latencyMs: 1500` |
   | `errorRate: 0` | `errorRate: 0.2` |
   | `memoryLeak: false` | `memoryLeak: true` |
   | `slowDb: false` | `slowDb: true` |

   Change nothing else: not the `image:` lines, not the indentation.
4. Commit changes → **Commit directly to the `main` branch**, with a message that does not name
   the setting. GitHub's own `Update values.yaml` is fine.
5. Tell the student only "done". Do not say which one, until the student's RCA is written.
