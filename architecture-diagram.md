# ShopLite: Architecture diagram

এখানে তিনটা ছবি আছে:

1. Infrastructure আর application কোথায় বসে।
2. Code কীভাবে Git থেকে cluster-এ পৌঁছায়।
3. Metrics, log আর trace কীভাবে Grafana-য় আসে।

GitHub নিচের block-গুলো নিজে থেকেই ছবি হিসেবে দেখায়। প্রতিটার PNG একই folder-এ আছে: `architecture-diagram.png`, `architecture-delivery-flow.png`, `architecture-observability-flow.png`।

## ১. Infrastructure আর application

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

**একটা order-এর পথ**

1. Browser থেকে request যায় ALB-তে, সেখান থেকে worker node-এর Traefik-এ।
2. Traefik `/` পাঠায় `web`-এ, আর `/api` পাঠায় `catalog-api`-তে।
3. `catalog-api` order-টা `PENDING` অবস্থায় PostgreSQL-এ রাখে, তারপর Redis-এর `orders:pending` list-এ ঠেলে দেয়। Message-এর সাথে trace context-ও যায়।
4. `order-worker` list থেকে order তুলে `PROCESSING` করে, ১–২ সেকেন্ড কাজ করে, তারপর `COMPLETED` লেখে।
5. Browser `GET /api/orders/{id}` দিয়ে status দেখে।

**ছবিটা পড়ার সময় যা মনে রাখবে**

- prod চলে `shoplite` namespace-এ (ALB-র port 80), dev চলে `shoplite-dev`-এ (port 8080)। দুটোই একই cluster-এ।
- তিনটা EC2-ই private subnet-এ, কোনোটার public IP নেই। ভেতরে ঢোকার পথ SSM Session Manager।
- Internet থেকে শুধু ALB-তে পৌঁছানো যায়। Node-এর security group শুধু ALB থেকে ingress-এর port-এ traffic নেয়।
- Node বাইরে যায় শুধু NAT Gateway দিয়ে, যেমন ECR থেকে image টানতে।
- PostgreSQL আর Redis-এ ঢুকতে পারে শুধু `catalog-api` আর `order-worker` (NetworkPolicy)।
- Monitoring আর ArgoCD-ও worker node-এই চলে, আলাদা namespace-এ।

## ২. Delivery: push থেকে cluster

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

- Pipeline শুধু image বানায় আর publish করে। Cluster-এ কিছু বসায় ArgoCD, Git থেকে পড়ে।
- AWS-এ ঢোকার জন্য pipeline-এ কোনো স্থায়ী key নেই; প্রতিবার OIDC দিয়ে অল্প সময়ের credential নেয়।
- dev-এ নতুন tag নিজে থেকেই বসে। prod-এ তুলতে `promote` workflow, তারপর হাতে sync।
- কেউ `kubectl` দিয়ে dev-এ কিছু বদলালে ArgoCD সেটা Git-এর অবস্থায় ফিরিয়ে আনে।

## ৩. Observability: তিন ধরনের signal

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

**Grafana-র ভেতরে তিনটা signal যেভাবে জোড়া লাগে**

- Latency panel-এর exemplar বিন্দুতে click করলে ওই request-এর trace খোলে (Prometheus → Tempo)।
- Log-এর `trace_id` থেকে সরাসরি trace-এ যাওয়া যায় (Loki → Tempo)।
- Trace থেকে ওই trace-এর সব log দেখা যায় (Tempo → Loki)।

এই তিনটা link থাকলেই একটা alert থেকে শুরু করে ঠিক যে request-টা ব্যর্থ হয়েছে সেখানে দুই মিনিটের মধ্যে পৌঁছানো যায়।
