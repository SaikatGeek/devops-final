# Root Cause Analysis: TODO short title (what customers saw)

| | |
|---|---|
| Date | TODO |
| Environment | prod: namespace `shoplite`, ALB port 80 |
| Status | Resolved |
| Duration | TODO, from the fault reaching prod to the recovery |
| Times | UTC+6, the clock of Grafana, Slack and the screenshots |
| Evidence | [`evidence/q8/`](evidence/q8/), procedure in [`evidence/q8/commands.md`](evidence/q8/commands.md) |

This RCA was written from Grafana's evidence alone (Prometheus, Loki, Tempo) and the Slack
alerts. The change itself was read only after it was written; see the last section.

## Summary

TODO: two or three sentences. What customers saw, for how long, what caused it, and how it
was fixed.

## Timeline

From the timeline kept during the exercise (`~/q8-timeline.txt`, `16-timeline.png`).

| Time | Event | Evidence |
|---|---|---|
| TODO | Load test started: 22 requests a second; the dashboard healthy | `01-baseline.png` |
| TODO | A commit to prod's values was synced to prod in ArgoCD | `03-prod-synced.png` |
| TODO | First symptom on the dashboard: TODO | `06-dashboard-fault.png` |
| TODO | First alert: TODO (severity) | `04-first-alert.png` |
| TODO | Logs: TODO | `07-logs.png` |
| TODO | Trace: TODO | `08-trace.png` |
| TODO | Root cause identified | `09-root-cause.png` |
| TODO | Revert pushed: TODO commit | `10-revert.png` |
| TODO | Revert synced to prod | `11-prod-synced-revert.png` |
| TODO | Dashboard back to normal | `12-dashboard-recovered.png` |
| TODO | Alert resolved in Slack | `13-slack-resolved.png` |

## Detection

TODO:

- which alert fired first, and when;
- why it fired: the rule's expression, threshold and `for` time
  (`monitoring/alert-rules/shoplite-alerts.yaml`), and the value that crossed it;
- how long after the change reached prod it fired, and why it took that long (the rule's
  rate window and its `for`).

## Investigation: dashboard → logs → trace

TODO, for each step: what was looked at, what it showed, and what it ruled out.

1. **Dashboard.** Which golden signal moved, on which route or pod, since when; the deploy
   mark at the start; what stayed normal (traffic, other routes, other pods, dependencies).
2. **Logs.** The query, the lines found, what they say.
3. **Trace.** The request opened, the span that holds the error or the time, and what the
   other spans show.

## Root cause

TODO: the component, how it behaved, since when, and the change that brought it, as found
before the change was read. Why that behaviour explains every symptom above.

## Recovery

The commit was reverted in shoplite-gitops (TODO revert commit), and prod synced in ArgoCD.
No kubectl was used.

| | From → to | Minutes |
|---|---|---|
| Time to detect | fault synced to prod → first alert | TODO |
| Time to identify | first alert → root cause written | TODO |
| Time to recover | first alert → dashboard back to normal | TODO |
| Total | fault synced to prod → dashboard back to normal | TODO |

## Impact

From the queries of the procedure's section 8 (`15-impact.png`), over the incident:

- failed requests (5xx), per route: TODO of TODO;
- worst p95 latency, per route: TODO;
- orders created / completed / failed: TODO;
- longest queue: TODO;
- container restarts: TODO.

## Preventive measure

TODO: one measure, concrete, and how it would have prevented this incident or made it
shorter.

## Check against the change (written after the RCA)

TODO: the fault's commit (hash; made by `scripts/chaos-pick.sh`, blind), what it changed, and
whether it matches the root cause above.
