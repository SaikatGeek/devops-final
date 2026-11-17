# NodeDiskFilling

| | |
|---|---|
| Severity | warning |
| Fires when | more than 85% of a node's root filesystem (`/`) is used, for 5 minutes |
| Labels | `instance` (the node's node-exporter, `<private IP>:9100`), `mountpoint`, `fstype` |
| Rule | `monitoring/alert-rules/shoplite-alerts.yaml` |

## Symptoms

The Slack message names the node and how full its disk is.

## Impact

Nothing yet, but at 100% the node cannot pull images or write logs. Before that, the kubelet
reports DiskPressure and evicts pods. PostgreSQL's data and Loki's chunks are PersistentVolumes
on a node's own disk (k3s's local-path), so a full disk stops their writes too.

## First five minutes (Grafana only)

1. In Explore (Prometheus), the use of each node's root disk, and how fast it grows (below).
   A steady climb is growing data; a jump is something written at once (for example many new
   images after deploys).
2. Which pods run on that node: `kube_pod_info` with the node's IP.
3. What grows on it: PostgreSQL (`postgres-0`) and Loki (`loki-0`) keep their data on their
   node's disk; container images and pod logs are on every node.

Queries for Explore:

```promql
1 - node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}
```

```promql
predict_linear(node_filesystem_avail_bytes{mountpoint="/"}[1h], 4 * 3600) < 0
```

```promql
kube_pod_info{host_ip="<the node's private IP>"}
```

## Likely causes and fixes

- **Old container images** from many deploys: remove the unused ones on that node
  (`sudo k3s crictl rmi --prune`, through an SSM session).
- **Logs or metrics growing faster than expected:** lower the retention of Loki or Prometheus
  in `monitoring/stack/` (Git), and let ArgoCD sync.
- **The database grows:** give the nodes a bigger disk in Terraform (the compute module's
  root volume) and apply, then grow the filesystem.

## Recovered when

The disk is back under 85%, and Slack shows the alert as RESOLVED.
