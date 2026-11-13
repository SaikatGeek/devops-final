#!/usr/bin/env bash
# Rehearses the ShopLite Helm chart on a local single-node k3s (the lab's version), no AWS:
#   1. build the three images, start k3s in Docker and load the images into it
#   2. helm lint with the dev and the prod values; the API server checks every rendered
#      prod manifest (server-side dry run)
#   3. create the database Secret (outside the chart, as in the lab) and install the chart
#      with the dev values
#   4. check: every pod ready, no container runs as root, every container has requests and
#      limits, the products are seeded, an order placed through web reaches COMPLETED, and a
#      changed setting rolls catalog-api and order-worker (the ConfigMap checksum)
#   5. remove everything again
# Needs only Docker (and internet for the first pulls). Run it from shoplite-app/:
#   bash helm/tests/run.sh
set -euo pipefail
cd "$(dirname "$0")/../.."

export MSYS_NO_PATHCONV=1 # Git Bash on Windows: leave container paths alone
HOST_DIR=$(pwd -W 2>/dev/null || pwd)
K3S_IMAGE=rancher/k3s:v1.37.2-k3s1 # the version Ansible installs in the lab
HELM_IMAGE=alpine/helm:4.3.1
NODE=shoplite-chart-test
NS=shoplite-dev
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

step "building the three images"
for s in web catalog-api order-worker; do
  docker build -q --target runtime -t "shoplite/$s:local" "services/$s" >/dev/null
done
for image in postgres:16-alpine redis:7.4-alpine "$HELM_IMAGE" "$K3S_IMAGE"; do
  docker image inspect "$image" >/dev/null 2>&1 || docker pull -q "$image" >/dev/null
done

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
  shoplite/order-worker:local postgres:16-alpine redis:7.4-alpine |
  docker exec -i "$NODE" ctr --namespace k8s.io images import - >/dev/null

step "helm lint, and the API server checks the rendered prod manifests"
helm lint shoplite --strict -f shoplite/values-dev.yaml | tail -n 1
helm lint shoplite --strict -f shoplite/values-prod.yaml | tail -n 1
kubectl create namespace shoplite-dryrun >/dev/null
helm template shoplite shoplite -n shoplite-dryrun -f shoplite/values-prod.yaml |
  kubectl apply -n shoplite-dryrun --dry-run=server -f - >/dev/null ||
  fail "the API server rejects the prod manifests"
echo "ok    Kubernetes $(kubectl version -o json | grep -m1 gitVersion | cut -d'"' -f4) accepts every prod manifest"

step "installing into $NS with the dev values (the Secret first, never in the chart)"
kubectl create namespace "$NS" >/dev/null
kubectl -n "$NS" create secret generic shoplite-db --from-literal=POSTGRES_USER=shoplite \
  --from-literal=POSTGRES_PASSWORD="$(head -c 24 /dev/urandom | base64 | tr -d '+/=')" >/dev/null
if ! helm install shoplite shoplite -n "$NS" -f shoplite/values-dev.yaml --wait --timeout 5m >/dev/null; then
  kubectl -n "$NS" get pods
  fail "the release did not become ready"
fi
kubectl -n "$NS" get statefulsets,deployments,services

step "every pod ready, none as root, every container with requests and limits"
kubectl -n "$NS" wait pods --all --for=condition=Ready --timeout=120s >/dev/null ||
  fail "not every pod is ready"
for pod in $(kubectl -n "$NS" get pods -o name); do
  for container in $(kubectl -n "$NS" get "$pod" -o jsonpath='{.spec.containers[*].name}'); do
    uid=$(kubectl -n "$NS" exec "$pod" -c "$container" -- id -u)
    [ "$uid" != "0" ] || fail "$pod/$container runs as root"
    echo "ok    ${pod#pod/} ($container) runs as uid $uid"
  done
done
missing=$(kubectl -n "$NS" get pods -o jsonpath='{range .items[*]}{range .spec.containers[*]}{.name}|{.resources.requests.cpu}|{.resources.requests.memory}|{.resources.limits.cpu}|{.resources.limits.memory}{"\n"}{end}{end}' |
  grep -E '\|\||\|$' || true)
[ -z "$missing" ] || fail "containers without requests or limits: $missing"
echo "ok    every container has CPU and memory requests and limits"

step "PostgreSQL seeded from files/init.sql"
products=$(kubectl -n "$NS" exec postgres-0 -- sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc "SELECT count(*) FROM products"')
[ "$products" -ge 10 ] || fail "only $products products seeded"
echo "ok    $products products"

step "an order placed through web reaches COMPLETED"
order=$(kubectl -n "$NS" exec deploy/web -- curl -sf -X POST -H 'Content-Type: application/json' \
  -d '{"product_id": 1, "quantity": 2}' http://127.0.0.1:8080/api/orders) ||
  fail "POST /api/orders through web failed"
id=$(echo "$order" | sed -n 's/.*"id": *\([0-9][0-9]*\).*/\1/p')
[ -n "$id" ] || fail "no order id in: $order"
status=""
for _ in $(seq 30); do
  status=$(kubectl -n "$NS" exec deploy/web -- curl -sf "http://127.0.0.1:8080/api/orders/$id" |
    sed -n 's/.*"status": *"\([A-Z]*\)".*/\1/p')
  [ "$status" = "COMPLETED" ] && break
  sleep 1
done
[ "$status" = "COMPLETED" ] || fail "order $id is $status, not COMPLETED"
echo "ok    order $id: web -> catalog-api -> PostgreSQL + Redis -> order-worker -> COMPLETED"

step "a changed setting rolls the pods that read it (ConfigMap checksum)"
# A Deployment's generation goes up when its pod template changes, i.e. when it rolls.
generation() { kubectl -n "$NS" get deployment "$1" -o jsonpath='{.metadata.generation}'; }
before_api=$(generation catalog-api)
before_worker=$(generation order-worker)
before_web=$(generation web)
helm upgrade shoplite shoplite -n "$NS" -f shoplite/values-dev.yaml --set config.logLevel=DEBUG \
  --wait --timeout 5m >/dev/null || fail "the upgrade did not become ready"
kubectl -n "$NS" rollout status deployment/catalog-api --timeout=120s >/dev/null
kubectl -n "$NS" rollout status deployment/order-worker --timeout=120s >/dev/null
[ "$(generation catalog-api)" -gt "$before_api" ] || fail "catalog-api did not roll"
[ "$(generation order-worker)" -gt "$before_worker" ] || fail "order-worker did not roll"
[ "$(generation web)" -eq "$before_web" ] || fail "web rolled although it does not read the ConfigMap"
echo "ok    catalog-api and order-worker rolled; web, which does not read the ConfigMap, did not"

echo
echo "PASS: the chart installs, runs non-root with limits, and an order completes"
