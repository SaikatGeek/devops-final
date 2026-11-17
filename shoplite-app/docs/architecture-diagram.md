# ShopLite: architecture diagram

Three pictures:

1. Where the infrastructure and the application run.
2. How code goes from Git to the cluster.
3. How metrics, logs and traces reach Grafana.

GitHub draws the blocks below as pictures. Each also exists as a PNG in this folder:
`architecture-diagram.png`, `architecture-delivery-flow.png`,
`architecture-observability-flow.png`.

## 1. Infrastructure and application

```mermaid
flowchart TB
    user(["User (browser)"])
    ecr[("Amazon ECR<br/>3 image repositories")]
    s3[("S3 bucket<br/>Terraform state + lock")]

    subgraph vpc["VPC 10.0.0.0/16 in two Availability Zones (all resources tagged project=shoplite)"]
        subgraph pub["Public subnets (AZ a, AZ b)"]
            alb["Application Load Balancer<br/>:80 prod, :8080 dev"]
            nat["NAT Gateway"]
        end
        subgraph priv["Private subnets (AZ a, AZ b): no public IP, admin access through SSM"]
            cp["EC2 control-plane<br/>k3s server"]
            subgraph workers["EC2 worker-1 and worker-2 (k3s agents)"]
                traefik["Traefik ingress<br/>NodePort 30080 / 30081"]
                argo["namespace argocd<br/>ArgoCD"]
                subgraph shop["namespaces shoplite, shoplite-dev"]
                    web["web<br/>Nginx, 2 pods"]
                    api["catalog-api<br/>2+ pods, PDB"]
                    redis[("Redis<br/>orders:pending")]
                    worker["order-worker<br/>HPA: 1 to 4 pods"]
                    pg[("PostgreSQL<br/>StatefulSet + PVC")]
                end
                mon["namespace monitoring<br/>Prometheus, Loki, Tempo,<br/>Grafana, Alertmanager, Alloy"]
            end
        end
    end

    user -- "HTTP" --> alb
    alb --> traefik
    traefik -- "/" --> web
    traefik -- "/api" --> api
    api -- "INSERT order" --> pg
    api -- "LPUSH" --> redis
    redis -- "BRPOP" --> worker
    worker -- "UPDATE status" --> pg
    ecr -. "image pull" .-> nat
    nat -. "nodes reach the internet only through NAT" .-> cp
    cp -. "k3s API" .-> traefik
    argo -. "deploys from Git" .-> api
    worker -. "metrics, logs, traces" .-> mon
```

**The path of one order**

1. The browser's request reaches the ALB, which sends it to Traefik on a worker node.
2. Traefik sends `/` to `web` and `/api` to `catalog-api`.
3. `catalog-api` stores the order in PostgreSQL as `PENDING`, then pushes it onto Redis's
   `orders:pending` list. The trace context travels inside the message.
4. `order-worker` takes the order from the list, sets it to `PROCESSING`, works for 1–2
   seconds, then writes `COMPLETED`.
5. The browser reads the status with `GET /api/orders/{id}`.

**Reading the picture**

- Prod runs in the namespace `shoplite` (ALB port 80), dev in `shoplite-dev` (ALB port
  8080), both in the same cluster.
- The three EC2 instances are in private subnets, without public IPs. Administrators reach
  them through SSM Session Manager.
- From the internet only the ALB can be reached. The nodes accept the ingress NodePorts only
  from the ALB.
- The nodes go out only through the NAT Gateway, for example to pull images from ECR.
- Only `catalog-api` and `order-worker` can reach PostgreSQL and Redis (NetworkPolicy).
- Monitoring and ArgoCD run on the worker nodes too, each in its own namespace.

## 2. Delivery: from a push to the cluster

```mermaid
flowchart TB
    dev(["Developer: git push to main<br/>(shoplite-app repository)"])

    subgraph ci["GitHub Actions: builds and publishes, never runs kubectl"]
        direction LR
        lint["Lint<br/>Hadolint, helm lint"] --> test["Tests"] --> build["Build 3 images<br/>tag = short Git SHA"] --> scan["Trivy scan<br/>fail on CRITICAL"]
    end

    ecr[("Amazon ECR")]

    subgraph gitops["shoplite-gitops repository"]
        direction LR
        devValues["envs/dev/values.yaml"] -- "promote workflow" --> prodValues["envs/prod/values.yaml"]
    end

    argo["ArgoCD (inside the cluster)<br/>reads shoplite-gitops"]
    devNs["shoplite-dev<br/>auto-sync + self-heal"]
    prodNs["shoplite (prod)<br/>manual sync"]

    dev --> ci
    ci -- "push images (OIDC)" --> ecr
    ci -- "commit new image tag" --> gitops
    gitops --> argo
    argo --> devNs
    argo --> prodNs
    ecr -. "image pull" .-> devNs
    ecr -. "image pull" .-> prodNs
```

- The pipeline only builds and publishes images. ArgoCD installs everything in the cluster,
  from Git.
- The pipeline holds no long-lived AWS key: every run gets short-lived credentials through
  OIDC.
- A new tag reaches dev on its own. Prod gets it through the `promote` workflow and a manual
  sync.
- If someone changes dev with `kubectl`, ArgoCD puts it back to the state in Git.
- Pull requests run the same lint, tests, build and scan, without AWS. A pull request that
  changes `terraform/` also gets the Terraform plan as a comment, through a read-only role.

## 3. Observability: three kinds of signal

```mermaid
flowchart LR
    apps["catalog-api<br/>order-worker<br/>(OpenTelemetry SDK)"]
    exporters["node-exporter<br/>kube-state-metrics"]

    prom["Prometheus"]
    alloy["Grafana Alloy<br/>DaemonSet"]
    loki["Loki"]
    tempo["Tempo"]
    am["Alertmanager"]
    slack(["Slack"])
    grafana["Grafana<br/>ShopLite — Golden Signals"]

    exporters --> prom
    apps -- "/metrics via ServiceMonitor" --> prom
    apps -- "JSON logs on stdout" --> alloy
    alloy --> loki
    apps -- "OTLP traces" --> tempo
    prom -- "5 alert rules" --> am
    am --> slack
    prom --> grafana
    loki --> grafana
    tempo --> grafana
```

**How Grafana joins the three signals**

- A click on an exemplar dot of the latency panel opens that request's trace (Prometheus →
  Tempo).
- A log line's `trace_id` opens its trace (Loki → Tempo).
- A trace shows all the log lines of that trace (Tempo → Loki).

With these three links, a reviewer goes from an alert to the exact request that failed in
under two minutes.
