Puku CLI


4 hour 59 min


Final Project: ShopLite — Build · Ship · Observe · Recover

Shrink
Final Capstone Assessment: ShopLite
Build · Ship · Observe · Recover
Submit link : https://forms.gle/chaLD1WDRatmgPod9
Deadline : 17-Nov-26
Course: Mastering DevOps and AWS
Platform: Poridhi
Batch: 03
Assessment Code: DEVOPS-CAP-601

Assessment Detail	Information
Total Marks	100 + 10 Bonus
Pass Mark	50
Distinction	80
Duration	10 Days
Assessment Mode	Individual
Total Questions	8 — All Compulsory
1. Project Overview
Scenario
You have joined a startup as its first DevOps Engineer. The founders want a small e-commerce backend called ShopLite that accepts orders, processes them in the background, and can be operated reliably in production.

You are responsible for the entire system, including:

Application development and containerization
Linux server administration and security
AWS infrastructure provisioning using Terraform
Configuration management and cluster setup using Ansible
Kubernetes deployment and workload management
Monitoring, logging, tracing, dashboards, and alerting
CI/CD automation and GitOps deployment
Production fault investigation, recovery, and Root Cause Analysis (RCA)
Your final challenge is to identify and resolve a production fault using only the observability tools you have built.

Target Architecture
Your implementation may differ in detail, but it must preserve the following architecture:

An AWS VPC spanning two Availability Zones
Two public subnets and two private subnets
A public Application Load Balancer (ALB)
One Kubernetes control-plane node and two worker nodes in private subnets
ShopLite application components deployed in Kubernetes
Amazon ECR for container image storage
GitHub Actions for CI/CD
ArgoCD for GitOps-based deployment
Prometheus, Loki, Tempo, and Grafana for observability
Alertmanager for notifications
Application flow:

A user accesses ShopLite through the ALB.
The frontend communicates with catalog-api.
The API stores orders in PostgreSQL and enqueues them in Redis.
order-worker processes queued orders and updates their status in PostgreSQL.
Metrics, logs, and traces are collected and correlated in Grafana.
GitHub Actions builds, tests, scans, and pushes images to ECR.
ArgoCD synchronizes the desired application state from the GitOps repository.
Question 1: Build the Application
Marks: 8 | Milestone 1 — Linux and Scripting

Develop ShopLite from scratch using Python, Go, or Node.js. No starter code is provided.

1.1 Required Components
Component	Responsibility	Requirements
web	Frontend	Static HTML/JavaScript served by Nginx. Users can list products, place orders, and view order status.
catalog-api	REST API	Lists products, accepts orders, and pushes order messages to the queue.
order-worker	Background worker	Consumes queued orders, simulates processing for 1–2 seconds, and updates order status.
postgres	Database	Stores products and orders. Automatically seed at least 10 products.
redis	Queue	Uses the Redis list orders:pending. Amazon SQS is permitted as a bonus alternative.
1.2 API Contract
Implement all endpoints with the correct HTTP status codes.

Method	Endpoint	Expected Behavior
GET	/products	Return all products.
GET	/products/{id}	Return a single product or 404 if it does not exist.
POST	/orders	Accept { "product_id": 1, "quantity": 2 }, create a PENDING order, enqueue it, and return 201 with the order ID.
GET	/orders/{id}	Return the order status: PENDING, PROCESSING, COMPLETED, or FAILED.
GET	/healthz	Liveness check indicating that the process is running.
GET	/readyz	Readiness check verifying that the database and queue are reachable.
GET	/metrics	Expose Prometheus metrics required in Question 6.
1.3 Database Schema
Create the following tables:

products

id
name
price
stock
orders

id
product_id
quantity
status
created_at
completed_at
Implement automatic database initialization and product seeding.

1.4 Implementation Requirements
(a) API implementation — 3 marks: Implement all endpoints with the correct behaviors and status codes.
(b) Database — 1 mark: Implement the required schema and automatic seeding.
(c) Configuration and logging — 2 marks: Read configuration from environment variables. Output JSON logs to stdout containing timestamp, level, service, message, and trace_id. Ensure the worker shuts down gracefully on SIGTERM.
(d) Unit testing — 1 mark: Write at least five API unit tests.
(e) Fault injection — 1 mark: Implement all four fault-injection flags below.
1.5 Fault-Injection Flags
All flags must be disabled by default and used during Question 8.

Environment Variable	Expected Effect
CHAOS_LATENCY_MS	Adds the specified delay to approximately 30% of GET /products/{id} requests.
CHAOS_ERROR_RATE	Returns HTTP 500 for the specified fraction of POST /orders requests. For example, 0.1 represents a 10% error rate.
CHAOS_MEMORY_LEAK	Causes the worker to retain a growing in-memory list for every processed order.
CHAOS_SLOW_DB	Makes the worker execute pg_sleep(2) before each database update.
Question 2: Containerization with Docker
Marks: 10 | Milestone 1 — Containerization

Containerize all ShopLite components and provide a reproducible local development environment.

Tasks
(a) Dockerfiles — 4 marks

Write Dockerfiles for web, catalog-api, and order-worker.
Use multi-stage builds.
Run containers as non-root users.
Include a HEALTHCHECK instruction.
Provide a .dockerignore file.
Keep each final image under 150 MB.
(b) Docker Compose — 3 marks

Create docker-compose.yml to run all five components.
Use a named volume for PostgreSQL data.
Configure health-check-based depends_on conditions.
(c) Smoke test — 2 marks

Create scripts/smoke-test.sh.
Start the application stack.
Wait until /readyz is available.
Place an order.
Poll the order until its status becomes COMPLETED.
Exit with a non-zero status if any step fails.
(d) Makefile — 1 mark

Provide the following targets:

build
up
down
test
smoke
Checkpoint
The following command must pass on a clean machine:

make up && make smoke
Question 3: Linux Server Administration
Marks: 5 | Milestones 1 & 2 — Linux, Permissions, systemd, and Networking

Harden and operate one Ubuntu 22.04 or 24.04 server. This may be an EC2 instance or a local virtual machine running the Docker Compose stack from Question 2.

For every task, submit the commands, configuration files, and terminal screenshots as evidence.

3.1 Users and SSH — 1.5 marks
Create a deploy user and an ops group.
Add deploy to the ops group.
Disable root login in sshd_config.
Disable password-based SSH authentication so only key-based login is allowed.
Demonstrate that both root login and password-based login are refused.
3.2 File Permissions — 1 mark
Configure /var/log/shoplite/ so it is readable by the ops group only.
Use chmod, chown, and exactly one setfacl rule.
Show the results using ls -l and getfacl.
Explain in one line why using permission mode 777 is incorrect.
3.3 systemd Backup Service — 1.5 marks
Create:

shoplite-backup.service
shoplite-backup.timer
Requirements:

Run a nightly pg_dump backup of the ShopLite database.
Store backups under /var/backups/shoplite/.
Configure Restart=on-failure.
Demonstrate the output of systemctl status and systemctl list-timers.
3.4 Firewall and Ports — 1 mark
Configure UFW or iptables.
Allow only inbound ports 22, 80, and 443.
Deny incoming traffic by default.
Demonstrate listening ports using ss -tulpn.
From another machine, use curl or nc to demonstrate one open port and one blocked port.
Safety requirement: Keep a second SSH session open while modifying SSH configuration or firewall rules to avoid locking yourself out of the server.

Question 4: AWS Infrastructure as Code
Marks: 17 | Milestones 2 & 3 — AWS, Terraform, and Ansible

Provision the AWS infrastructure using Terraform. The AWS console may be used only to check billing.

Tasks
(a) VPC and Networking — 4 marks

Create a custom VPC spanning two Availability Zones.
Create two public and two private subnets.
Configure an Internet Gateway.
Configure a NAT Gateway or NAT instance.
(b) Security Groups — 3 marks

Define least-privilege security groups.
Ensure Kubernetes nodes are not directly reachable from the internet.
(c) Kubernetes Infrastructure — 1 mark

Launch one control-plane EC2 instance and two worker EC2 instances in private subnets.
Provide administrative access through a bastion host or AWS Systems Manager Session Manager, with SSM preferred.
(d) Application Load Balancer — 2 marks

Create an ALB in the public subnets.
Forward traffic to the Kubernetes ingress.
Add a Route 53 record if a domain is available.
(e) ECR and Remote State — 2 marks

Create ECR repositories for all three application images.
Store Terraform state remotely in S3 with state locking.
(f) Terraform Modules — 1 mark

Organize the Terraform code into reusable modules:

network
compute
alb
ecr
(g) Ansible Configuration — 4 marks

Apply the hardening requirements from Question 3 to every node.
Install the container runtime.
Bootstrap the Kubernetes cluster using kubeadm or k3s.
Join the worker nodes.
Retrieve the kubeconfig.
Cost Guard
Tag every AWS resource with project=shoplite.
Create an AWS Budget alarm at USD 20.
Run terraform destroy after grading to avoid unnecessary costs.
Question 5: Kubernetes Deployment
Marks: 15 | Milestone 4 — Kubernetes

Deploy ShopLite into the shoplite namespace and package the application as a single Helm chart.

5.1 Workload Requirements
Component	Kubernetes Resource	Requirements
web	Deployment	Two replicas, resource requests and limits, Ingress path /.
catalog-api	Deployment	At least two replicas, liveness probe /healthz, readiness probe /readyz, PodDisruptionBudget with minAvailable: 1, and Ingress path /api.
order-worker	Deployment	CPU-based HPA with minimum one and maximum four replicas. Configure a termination grace period long enough to finish an order.
postgres	StatefulSet	PersistentVolumeClaim for data and an initialization Job or script to seed products.
redis	Deployment	ClusterIP Service only.
5.2 Tasks
(a) Workloads and Security — 7 marks

Implement all workloads listed above.
Configure resource requests and limits on every pod.
Ensure no container runs as root.
(b) Secrets and Configuration — 2 marks

Store database credentials in a Kubernetes Secret.
Store application settings in a ConfigMap.
Never commit plain-text secrets to Git.
(c) NetworkPolicy — 2 marks

Allow only catalog-api and order-worker to access PostgreSQL and Redis.
(d) Ingress Controller — 1 mark

Install ingress-nginx or Traefik behind the ALB.
(e) Helm Chart — 3 marks

Package everything into a single Helm chart.
Provide separate values files for development and production.
Checkpoint
Place an order through the browser using the ALB URL and verify that the order reaches COMPLETED.

Question 6: Observability
Marks: 25 | Milestone 5 — Monitoring, Logging, and Tracing

Build an observability system that allows a reviewer to trace an alert to the exact failing request in under two minutes using Grafana alone.

6.1 Required Observability Stack
Signal or Function	Tool	Requirements
Metrics	Prometheus (kube-prometheus-stack)	Scrape node-exporter, kube-state-metrics, and application metrics through ServiceMonitor resources.
Logs	Loki + Promtail or Grafana Alloy	Collect all pod logs and parse JSON fields.
Traces	Tempo + OpenTelemetry SDK	Instrument the API and worker and export traces using OTLP.
Dashboards	Grafana	Provision dashboards as JSON files committed to Git.
Alerts	Alertmanager	Send notifications to Slack, email, or a webhook.
Deploy the observability stack in the monitoring namespace.

6.2 Required Application Metrics
Expose all six metrics through the application's /metrics endpoint.

Metric	Type	Labels
http_requests_total	Counter	method, route, status
http_request_duration_seconds	Histogram	method, route
orders_created_total	Counter	None
orders_processed_total	Counter	result
order_queue_depth	Gauge	None
order_processing_seconds	Histogram	None
6.3 Golden Signals Dashboard — 5 marks
Create a ShopLite — Golden Signals Grafana dashboard displaying:

p50, p95, and p99 request latency per route
Requests per second
HTTP 5xx error rate
CPU and memory usage per pod
Order queue depth
Worker replica count
Orders created versus orders processed
6.4 Trace and Signal Correlation — 6 marks
Propagate trace context through the queue.
Ensure one order can be followed through a complete trace: API → queue → worker → database.
Link trace_id in Loki to the corresponding Tempo trace.
Enable exemplars on latency histograms.
6.5 Required Alerts — 4 marks
Configure all five alerts. Each alert must include a severity label and a runbook_url pointing to a runbook in your repository.

Alert	Condition	Severity
HighErrorRate	HTTP 5xx rate exceeds 5% for 5 minutes.	Critical
HighLatency	p95 latency exceeds 1 second for 5 minutes.	Warning
QueueBacklog	order_queue_depth exceeds 50 for 10 minutes.	Warning
PodCrashLooping	Pod restarts are increasing over 10 minutes.	Critical
NodeDiskFilling	Disk usage exceeds 85%.	Warning
6.6 Task Breakdown
(a) Observability stack — 5 marks: Deploy the complete monitoring, logging, tracing, dashboard, and alerting stack.
(b) Application metrics — 5 marks: Expose all six required application metrics.
(c) Golden Signals dashboard — 5 marks: Build the dashboard with all required panels.
(d) Signal correlation — 6 marks: Correlate metrics, logs, and traces across the complete order lifecycle.
(e) Alerts and runbooks — 4 marks: Configure all five alerts with severity labels and repository runbook URLs.
Question 7: CI/CD and GitOps
Marks: 10 | Milestone 6 — GitHub Actions and ArgoCD

Implement a complete CI/CD and GitOps workflow using two repositories:

shoplite-app — Application code, Dockerfiles, Terraform, Helm chart, monitoring configuration, and CI workflows.
shoplite-gitops — ArgoCD Applications and environment-specific Helm values.
Important: The CI/CD pipeline must never run kubectl apply. GitHub Actions builds and publishes artifacts; ArgoCD deploys the desired state from Git.

7.1 Tasks
(a) Main-branch pipeline — 5 marks

On every push to main:

Run linting, including Hadolint and helm lint.
Run tests.
Build application images tagged with the short Git SHA.
Scan images using Trivy and fail the pipeline on CRITICAL vulnerabilities.
Push images to ECR using OpenID Connect (OIDC).
Commit the new image tag to shoplite-gitops.
(b) Pull-request pipeline — 1 mark

Run lint, tests, builds, and security scans on pull requests.
When terraform/ changes, post the Terraform plan as a pull-request comment.
(c) ArgoCD configuration — 3 marks

Configure one ArgoCD Application per environment.
Enable automatic synchronization for development.
Require manual synchronization for production.
Enable self-healing.
(d) Self-healing demonstration — 1 mark

Manually edit a Kubernetes resource using kubectl.
Demonstrate that ArgoCD reverts the manual change to match the desired Git state.
Checkpoint
Change the page title in the web application, push the change to Git, and demonstrate that it reaches the browser without running any manual deployment command.

Question 8: Chaos Day and Root Cause Analysis
Marks: 10 | All Milestones — Production Troubleshooting

A peer or the instructor will secretly enable one of the fault-injection flags from Question 1. Your task is to identify and recover from the production fault using observability alone.

8.1 Exercise Procedure
Grant a peer write access to shoplite-gitops for one hour.
The peer enables one chaos flag in the production values file and commits it with an innocuous commit message.
Run a load test for 15 minutes at 20 or more requests per second, using k6, hey, or a script.
Do not inspect the Git diff or pod environment variables until the RCA has been written.
Use only Grafana, Prometheus, Loki, and Tempo to investigate the fault.
Recover by reverting the Git commit and allowing ArgoCD to synchronize the corrected state.
8.2 Assessment Tasks
(a) Chaos exercise — 3 marks

Complete the exercise as described.
Preserve screenshots and timestamps as evidence.
(b) Root Cause Analysis — 5 marks

Write a 1–2 page RCA covering:
Incident timeline
Detection: first alert and why it triggered
Investigation: dashboard → logs → trace
Identified root cause
Recovery time
One preventive measure
(c) Recovery — 2 marks

Recover the application by reverting the change through Git.
Demonstrate the recovery on the Grafana dashboard.
Important: The RCA is graded on the quality of your reasoning and evidence, not on how quickly you find the fault.

2. Submission Requirements
2.1 Repository Structure
Maintain two Git repositories with the following structure.

Repository 1: shoplite-app
shoplite-app/
├── services/
│   ├── web/
│   ├── catalog-api/
│   └── order-worker/
├── docker-compose.yml
├── Makefile
├── scripts/
│   └── smoke-test.sh
├── linux/
│   ├── sshd_config
│   ├── systemd/
│   ├── firewall/
│   └── evidence/
├── terraform/
│   └── modules/
│       ├── network/
│       ├── compute/
│       ├── alb/
│       └── ecr/
├── ansible/
├── helm/
│   └── shoplite/
├── monitoring/
│   ├── dashboards/
│   ├── alert-rules/
│   └── runbooks/
├── .github/
│   └── workflows/
└── docs/
    ├── architecture-diagram
    └── RCA
Repository 2: shoplite-gitops
shoplite-gitops/
├── apps/
│   └── argocd-applications
└── envs/
    ├── dev/
    │   └── values.yaml
    └── prod/
        └── values.yaml
Use appropriate filenames and extensions for all configuration files. Include any additional files needed to make the project reproducible.

2.2 Evidence and Documentation
Submit the following as part of your repositories and assessment evidence:

Architecture diagram
Application source code and unit tests
Dockerfiles and Docker Compose configuration
Smoke-test script and Makefile
Linux configuration files and terminal screenshots
Terraform modules and Ansible playbooks
Kubernetes manifests and Helm chart
Monitoring dashboards, alert rules, and runbooks
CI/CD workflow files and GitOps configuration
Screenshots demonstrating the required checkpoints
Root Cause Analysis document
Do not commit credentials, access keys, passwords, or plain-text secrets to Git.

3. Live Demonstration
Duration: 10 minutes

Be prepared to demonstrate the following:

 Walk through the architecture using your own diagram.
 Show a code change flowing from Git push to the browser.
 Show the Golden Signals dashboard under load.
 Open one complete order trace and access its logs from the trace.
 Demonstrate ArgoCD self-healing after a manual kubectl edit.
4. Marking Scheme
Question	Assessment Area	Marks
Q1	Application Development	8
Q2	Docker and Containerization	10
Q3	Linux Server Administration	5
Q4	AWS and Infrastructure as Code	17
Q5	Kubernetes Deployment	15
Q6	Observability	25
Q7	CI/CD and GitOps	10
Q8	Chaos Engineering and RCA	10
Total		100
Bonus	Optional Advanced Tasks	+10
Full-Marks Expectations
Area	Expected Outcome
Application	Correct API behavior, JSON logs, graceful shutdown, and working chaos flags.
Docker	Small, non-root images; reproducible stack; passing smoke test.
Linux	Key-only SSH, correct ACLs, working backup timer, and only the required inbound ports open.
AWS and IaC	Modular Terraform, private cluster nodes, remote state, and idempotent Ansible.
Kubernetes	Working probes, HPA, PDB, NetworkPolicy, and no secrets in Git.
Observability	Correlated metrics, logs, and traces; dashboards and alerts managed as code.
CI/CD and GitOps	OIDC, vulnerability scan gate, no kubectl deployment in the pipeline, and demonstrated self-healing.
Chaos and RCA	Clear evidence chain and recovery through Git.
Passing score: 50/100
Distinction: 80/100

5. Bonus Tasks
Up to +10 marks — Attempt only after completing Q1–Q8.

Bonus 1 — Amazon EKS: +3 marks

Run the cluster on Amazon EKS using Terraform.
Use IRSA or EKS Pod Identity for AWS access.
Bonus 2 — Amazon SQS and Lambda: +3 marks

Replace Redis with Amazon SQS.
Add a Lambda function that emits an order-confirmation event.
Bonus 3 — Canary Deployment: +2 marks

Use Argo Rollouts to implement a canary release for catalog-api.
Automatically abort the rollout based on Prometheus error-rate analysis.
Bonus 4 — SLO and Burn-Rate Alerting: +2 marks

Define an SLO for POST /orders, such as 99% of requests completing in under 500 ms.
Configure a multi-window burn-rate alert.
6. Final Instructions
This is an individual assessment.
All eight compulsory questions must be completed within the 10-day assessment period.
Follow the required architecture, security, observability, and deployment practices.
Preserve evidence for all checkpoints and demonstrations.
Ensure your project can be reviewed and reproduced from the submitted repositories.
Clean up billable AWS resources after grading by running terraform destroy.
Build it. Ship it. Observe it. Recover it.
