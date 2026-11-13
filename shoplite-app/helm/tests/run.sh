#!/usr/bin/env bash
# Rehearses the ShopLite Helm chart on a local single-node k3s (the lab's version), no AWS:
#   1. build the three images, start k3s in Docker and load the images into it
#   2. helm lint with the dev and the prod values
#   3. install Traefik exactly as shoplite-gitops/apps/traefik.yaml describes it (chart,
#      version, values), then let the API server check every rendered prod manifest
#   4. create each environment's database Secret (outside the chart, as in the lab) and
#      install the chart twice: dev values into shoplite-dev, prod values into shoplite
#   5. check: every pod ready, no container runs as root, every container has requests and
#      limits, the products are seeded, an order reaches COMPLETED (through web's own /api
#      proxy, and through Traefik's NodePorts like the ALB), /ping answers on both
#      NodePorts, each NodePort reaches its own environment, a changed setting rolls the
#      pods that read it, the HPA adds workers under load, and the PDB lets a drain take
#      only one catalog-api pod per environment
#   6. remove everything again
# Needs Docker and internet (Traefik's chart). Run it from shoplite-app/, with
# shoplite-gitops next to it (as in this repository, or both repositories cloned side by
# side; SHOPLITE_GITOPS_DIR overrides the path):
#   bash helm/tests/run.sh
set -euo pipefail
cd "$(dirname "$0")/../.."

export MSYS_NO_PATHCONV=1 # Git Bash on Windows: leave container paths alone
HOST_DIR=$(pwd -W 2>/dev/null || pwd)
GITOPS_DIR=${SHOPLITE_GITOPS_DIR:-../shoplite-gitops}
TRAEFIK_APP="$GITOPS_DIR/apps/traefik.yaml"
K3S_IMAGE=rancher/k3s:v1.37.2-k3s1 # the version Ansible installs in the lab
HELM_IMAGE=alpine/helm:4.3.1
YQ_IMAGE=mikefarah/yq:4.54.1
NODE=shoplite-chart-test
DEV=shoplite-dev
PROD=shoplite
WORK=$(mktemp -d)
WORK_HOST=$(cd "$WORK" && (pwd -W 2>/dev/null || pwd))

cleanup() { docker rm -f -v "$NODE" >/dev/null 2>&1 || true; rm -rf "$WORK"; }
trap cleanup EXIT
docker rm -f -v "$NODE" >/dev/null 2>&1 || true # leftover of an interrupted earlier run

step() { echo "==> $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }
# kubectl inside the k3s container; helm in its own container on the same network.
kubectl() { docker exec -i "$NODE" kubectl "$@"; }
helm() {
  docker run --rm -i --network "container:$NODE" -v "$HOST_DIR/helm:/helm:ro" \
    -v "$WORK_HOST:/work" -e KUBECONFIG=/work/kubeconfig -w /helm "$HELM_IMAGE" "$@"
}
yq() { docker run --rm -i "$YQ_IMAGE" "$@" <"$TRAEFIK_APP"; }
# curl from the k3s node's own network, like the ALB reaching a NodePort.
node_curl() { docker run --rm --network "container:$NODE" --entrypoint curl shoplite/web:local "$@"; }

[ -f "$TRAEFIK_APP" ] || fail "$TRAEFIK_APP not found (set SHOPLITE_GITOPS_DIR)"

step "building the three images"
for s in web catalog-api order-worker; do
  docker build -q --target runtime -t "shoplite/$s:local" "services/$s" >/dev/null
done
for image in postgres:16-alpine redis:7.4-alpine "$HELM_IMAGE" "$K3S_IMAGE" "$YQ_IMAGE"; do
  docker image inspect "$image" >/dev/null 2>&1 || docker pull -q "$image" >/dev/null
done

step "reading Traefik's chart, version and values from $TRAEFIK_APP"
TRAEFIK_REPO=$(yq '.spec.source.repoURL')
TRAEFIK_CHART=$(yq '.spec.source.chart')
TRAEFIK_VERSION=$(yq '.spec.source.targetRevision')
yq '.spec.source.helm.valuesObject' >"$WORK/traefik-values.yaml"
TRAEFIK_IMAGE="traefik:$(docker run --rm "$HELM_IMAGE" show chart "$TRAEFIK_CHART" --repo "$TRAEFIK_REPO" \
  --version "$TRAEFIK_VERSION" | sed -n 's/^appVersion: *//p')"
echo "chart $TRAEFIK_CHART $TRAEFIK_VERSION from $TRAEFIK_REPO, image $TRAEFIK_IMAGE"
docker image inspect "$TRAEFIK_IMAGE" >/dev/null 2>&1 || docker pull -q "$TRAEFIK_IMAGE" >/dev/null

step "starting k3s ($K3S_IMAGE)"
# Kubernetes 1.35+ refuses cgroup v1, which Docker Desktop on WSL2's default kernel runs;
# the lab's EC2 nodes run cgroup v2 and need nothing.
KUBELET_ARGS=()
if [ "$(docker info --format '{{.CgroupVersion}}')" = "1" ]; then
  KUBELET_ARGS=(--kubelet-arg=fail-cgroupv1=false)
  echo "note: this Docker host runs cgroup v1; the test kubelet gets fail-cgroupv1=false"
fi
# k3s's data folder is a volume: containerd's overlayfs cannot sit on the container's own.
docker run -d --name "$NODE" --hostname "$NODE" --privileged --cgroupns=private \
  --tmpfs /run --tmpfs /var/run -v /var/lib/rancher/k3s \
  "$K3S_IMAGE" server --disable=traefik "${KUBELET_ARGS[@]}" >/dev/null
for _ in $(seq 90); do
  kubectl get node "$NODE" --no-headers 2>/dev/null | grep -q ' Ready ' && break
  sleep 2
done
kubectl get node "$NODE" --no-headers | grep -q ' Ready ' || fail "k3s did not become Ready"
docker exec "$NODE" cat /etc/rancher/k3s/k3s.yaml >"$WORK/kubeconfig"

step "loading the images into k3s (no registry needed)"
docker save --platform linux/amd64 shoplite/web:local shoplite/catalog-api:local \
  shoplite/order-worker:local postgres:16-alpine redis:7.4-alpine "$TRAEFIK_IMAGE" |
  docker exec -i "$NODE" ctr --namespace k8s.io images import - >/dev/null

step "helm lint"
helm lint shoplite --strict -f shoplite/values-dev.yaml | tail -n 1
helm lint shoplite --strict -f shoplite/values-prod.yaml | tail -n 1

step "installing Traefik as shoplite-gitops describes it"
helm install traefik "$TRAEFIK_CHART" --repo "$TRAEFIK_REPO" --version "$TRAEFIK_VERSION" \
  -n traefik --create-namespace -f /work/traefik-values.yaml --wait --timeout 5m >/dev/null ||
  fail "Traefik did not become ready"
kubectl -n traefik get service traefik

step "the API server checks every rendered prod manifest (server-side dry run)"
kubectl create namespace shoplite-dryrun >/dev/null
helm template shoplite shoplite -n shoplite-dryrun -f shoplite/values-prod.yaml |
  kubectl apply -n shoplite-dryrun --dry-run=server -f - >/dev/null ||
  fail "the API server rejects the prod manifests"
echo "ok    Kubernetes $(kubectl version -o json | grep -m1 gitVersion | cut -d'"' -f4) accepts every prod manifest"

step "installing dev ($DEV) and prod ($PROD), each Secret first, never in the chart"
for env in dev prod; do
  ns=$DEV
  [ "$env" = prod ] && ns=$PROD
  kubectl create namespace "$ns" >/dev/null
  kubectl -n "$ns" create secret generic shoplite-db --from-literal=POSTGRES_USER=shoplite \
    --from-literal=POSTGRES_PASSWORD="$(head -c 24 /dev/urandom | base64 | tr -d '+/=')" >/dev/null
  if ! helm install shoplite shoplite -n "$ns" -f "shoplite/values-$env.yaml" --wait --timeout 5m >/dev/null; then
    kubectl -n "$ns" get pods
    fail "the $env release did not become ready"
  fi
done
kubectl -n "$PROD" get statefulsets,deployments,services,ingresses,pdb,hpa

step "every pod ready, none as root, every container with requests and limits"
for ns in $DEV $PROD; do
  kubectl -n "$ns" wait pods --all --for=condition=Ready --timeout=120s >/dev/null ||
    fail "not every pod in $ns is ready"
  for pod in $(kubectl -n "$ns" get pods -o name); do
    for container in $(kubectl -n "$ns" get "$pod" -o jsonpath='{.spec.containers[*].name}'); do
      uid=$(kubectl -n "$ns" exec "$pod" -c "$container" -- id -u)
      [ "$uid" != "0" ] || fail "$ns/$pod/$container runs as root"
      echo "ok    $ns: ${pod#pod/} ($container) runs as uid $uid"
    done
  done
  missing=$(kubectl -n "$ns" get pods -o jsonpath='{range .items[*]}{range .spec.containers[*]}{.name}|{.resources.requests.cpu}|{.resources.requests.memory}|{.resources.limits.cpu}|{.resources.limits.memory}{"\n"}{end}{end}' |
    grep -E '\|\||\|$' || true)
  [ -z "$missing" ] || fail "containers in $ns without requests or limits: $missing"
done
echo "ok    every container in both environments has CPU and memory requests and limits"

step "PostgreSQL seeded from files/init.sql"
db_count() { kubectl -n "$1" exec postgres-0 -- sh -c "psql -U \"\$POSTGRES_USER\" -d \"\$POSTGRES_DB\" -tAc \"$2\""; }
products=$(db_count "$DEV" "SELECT count(*) FROM products")
[ "$products" -ge 10 ] || fail "only $products products seeded"
echo "ok    $products products"

# place_order <curl to use> <base URL>: prints the new order's id, then waits for COMPLETED.
place_order() {
  local how=$1 base=$2 order id status=""
  order=$($how -sf -X POST -H 'Content-Type: application/json' -d '{"product_id": 1, "quantity": 2}' \
    "$base/api/orders") || fail "POST $base/api/orders failed"
  id=$(echo "$order" | sed -n 's/.*"id": *\([0-9][0-9]*\).*/\1/p')
  [ -n "$id" ] || fail "no order id in: $order"
  for _ in $(seq 30); do
    status=$($how -sf "$base/api/orders/$id" | sed -n 's/.*"status": *"\([A-Z]*\)".*/\1/p')
    [ "$status" = "COMPLETED" ] && break
    sleep 1
  done
  [ "$status" = "COMPLETED" ] || fail "order $id via $base is $status, not COMPLETED"
  echo "$id"
}
web_curl() { kubectl -n "$DEV" exec deploy/web -- curl "$@"; }

step "an order through web's own /api proxy reaches COMPLETED"
id=$(place_order web_curl http://127.0.0.1:8080)
echo "ok    order $id: web -> catalog-api -> PostgreSQL + Redis -> order-worker -> COMPLETED"

step "Traefik: /ping on both NodePorts (the ALB's health check), each NodePort its own environment"
for port in 30080 30081; do
  answer=$(node_curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$port/ping")
  [ "$answer" = "200" ] || fail "/ping on NodePort $port answered $answer"
  page=$(node_curl -sf "http://127.0.0.1:$port/") || fail "no page on NodePort $port"
  echo "$page" | grep -q '<title>' || fail "NodePort $port did not return the page"
  node_curl -sf "http://127.0.0.1:$port/api/products/1" | grep -q '"name"' ||
    fail "/api/products/1 on NodePort $port failed"
  echo "ok    NodePort $port: /ping 200, page at /, catalog-api at /api"
done
prod_before=$(db_count "$PROD" "SELECT count(*) FROM orders")
dev_before=$(db_count "$DEV" "SELECT count(*) FROM orders")
id=$(place_order node_curl http://127.0.0.1:30080)
[ "$(db_count "$PROD" "SELECT count(*) FROM orders")" -eq $((prod_before + 1)) ] ||
  fail "the order through NodePort 30080 did not land in prod"
[ "$(db_count "$DEV" "SELECT count(*) FROM orders")" -eq "$dev_before" ] ||
  fail "the order through NodePort 30080 reached dev"
echo "ok    order $id through NodePort 30080 (the ALB's port 80) is COMPLETED, in prod's database only"
id=$(place_order node_curl http://127.0.0.1:30081)
echo "ok    order $id through NodePort 30081 (the ALB's port 8080) is COMPLETED in dev"

step "a changed setting rolls the pods that read it (ConfigMap checksum)"
# A Deployment's generation goes up when its pod template changes, i.e. when it rolls.
generation() { kubectl -n "$DEV" get deployment "$1" -o jsonpath='{.metadata.generation}'; }
before_api=$(generation catalog-api)
before_worker=$(generation order-worker)
before_web=$(generation web)
helm upgrade shoplite shoplite -n "$DEV" -f shoplite/values-dev.yaml --set config.logLevel=DEBUG \
  --wait --timeout 5m >/dev/null || fail "the upgrade did not become ready"
kubectl -n "$DEV" rollout status deployment/catalog-api --timeout=120s >/dev/null
kubectl -n "$DEV" rollout status deployment/order-worker --timeout=120s >/dev/null
[ "$(generation catalog-api)" -gt "$before_api" ] || fail "catalog-api did not roll"
[ "$(generation order-worker)" -gt "$before_worker" ] || fail "order-worker did not roll"
[ "$(generation web)" -eq "$before_web" ] || fail "web rolled although it does not read the ConfigMap"
echo "ok    catalog-api and order-worker rolled; web, which does not read the ConfigMap, did not"

step "HorizontalPodAutoscaler: a burst of orders makes the dev worker scale out (1 to 4)"
# 400 orders at once through Traefik; each one costs the worker about 0.2 s of CPU.
docker run --rm --network "container:$NODE" --entrypoint sh shoplite/web:local -c '
  for i in $(seq 400); do
    curl -s -o /dev/null -X POST -H "Content-Type: application/json" \
      -d "{\"product_id\": 1, \"quantity\": 1}" http://127.0.0.1:30081/api/orders &
  done
  wait'
replicas=1
for _ in $(seq 36); do
  replicas=$(kubectl -n "$DEV" get hpa order-worker -o jsonpath='{.status.desiredReplicas}')
  [ "${replicas:-1}" -gt 1 ] && break
  sleep 5
done
kubectl -n "$DEV" get hpa order-worker
[ "${replicas:-1}" -gt 1 ] || fail "the HPA did not add workers under load"
[ "$replicas" -le 4 ] || fail "the HPA went above 4 workers"
echo "ok    the HPA scaled order-worker from 1 to $replicas"

step "PodDisruptionBudget: a node drain may take only one catalog-api pod per environment"
drain=$(kubectl drain "$NODE" --pod-selector=app.kubernetes.io/name=catalog-api --timeout=25s 2>&1 || true)
echo "$drain" | grep -m1 'disruption budget' || { echo "$drain" | tail -n 5; fail "no eviction was refused"; }
for ns in $DEV $PROD; do
  ready=$(kubectl -n "$ns" get deployment catalog-api -o jsonpath='{.status.readyReplicas}')
  [ "$ready" = "1" ] || fail "$ns has $ready ready catalog-api pods during the drain, expected exactly 1"
done
node_curl -sf http://127.0.0.1:30080/api/products/1 >/dev/null || fail "prod's API stopped answering during the drain"
echo "ok    one catalog-api pod per environment evicted, the second refused; the API kept answering"
kubectl uncordon "$NODE" >/dev/null
for ns in $DEV $PROD; do
  kubectl -n "$ns" rollout status deployment/catalog-api --timeout=120s >/dev/null
done

echo
echo "PASS: Traefik and both environments install; non-root, limits, Ingress, PDB and HPA work"
