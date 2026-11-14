#!/usr/bin/env bash
# Rehearses the GitOps bootstrap (scripts/bootstrap-cluster.sh) on a local k3s, without AWS
# and without GitHub:
#   1. build the three images, a test Git server (smart HTTP) and a tools image (bash,
#      kubectl and helm: what the lab machine needs); start k3s and load the images into it
#   2. publish the current shoplite-app and shoplite-gitops folders as two repositories on
#      the test server; in the gitops copy only, point the Applications at that server
#      instead of GitHub and write the image tag the way CI will (the images just built)
#   3. run scripts/bootstrap-cluster.sh against the cluster, then once more: the rerun
#      keeps both database Secrets unchanged
#   4. check: root -> traefik -> shoplite-dev become Synced and Healthy on their own; the
#      ShopLite Applications (wave 1) appear only after Traefik (wave 0) is available;
#      shoplite-prod stays OutOfSync, with nothing deployed, until it is synced by hand;
#      ArgoCD answers at /argocd on the web NodePort (the ALB's port 80) and its API wants
#      the admin login; the manual prod sync goes through that API, as the UI's Sync
#      button does; orders through both NodePorts reach COMPLETED; a kubectl change in
#      dev is reverted by self-heal (question 7d) while the same change in prod stays
#      and shows as OutOfSync
#   5. remove everything again
# Needs Docker and internet (the charts and images of Traefik and ArgoCD). About 15
# minutes. Run it from shoplite-app/, with shoplite-gitops next to it
# (SHOPLITE_GITOPS_DIR overrides the path):
#   bash scripts/tests/bootstrap-cluster.sh
set -euo pipefail
cd "$(dirname "$0")/../.."

export MSYS_NO_PATHCONV=1 # Git Bash on Windows: leave container paths alone
HOST_DIR=$(pwd -W 2>/dev/null || pwd)
GITOPS_DIR=${SHOPLITE_GITOPS_DIR:-../shoplite-gitops}
K3S_IMAGE=rancher/k3s:v1.37.2-k3s1 # the version Ansible installs in the lab
HELM_IMAGE=alpine/helm:4.3.1
YQ_IMAGE=mikefarah/yq:4.54.1
NODE=shoplite-gitops-test
GIT=shoplite-gitops-test-git
NET=shoplite-gitops-test
# k3s's CoreDNS cannot resolve Docker's container names, so the Git server gets a fixed IP.
SUBNET=172.30.0.0/24
GIT_IP=172.30.0.10
APP_URL=https://github.com/SaikatGeek/shoplite-app.git
GITOPS_URL=https://github.com/SaikatGeek/shoplite-gitops.git
WORK=$(mktemp -d)
WORK_HOST=$(cd "$WORK" && (pwd -W 2>/dev/null || pwd))

remove_containers() {
  docker rm -f -v "$NODE" "$GIT" >/dev/null 2>&1 || true
  docker network rm "$NET" >/dev/null 2>&1 || true
}
trap 'remove_containers; rm -rf "$WORK"' EXIT
remove_containers # leftovers of an interrupted earlier run

step() { echo "==> $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }
kubectl() { docker exec -i "$NODE" kubectl "$@"; }
yq() { docker run --rm -i "$YQ_IMAGE" "$@"; }
# curl from the k3s node's own network, like the ALB reaching a NodePort.
node_curl() { docker run --rm --network "container:$NODE" --entrypoint curl shoplite/web:local "$@"; }
# The lab machine: bash, kubectl and helm, reaching the API server on 127.0.0.1:6443 (here
# on the node's own network; in the lab through the kubectl_tunnel SSM port forward).
lab_machine() {
  docker run --rm -i --network "container:$NODE" -v "$HOST_DIR:/work/shoplite-app:ro" \
    -v "$WORK_HOST/gitops:/work/shoplite-gitops:ro" -v "$WORK_HOST/kube:/kube:ro" \
    -e KUBECONFIG=/kube/config -w /work/shoplite-app shoplite/gitops-test-tools "$@"
}
# app_state <name>: "<sync status> <health status>" of an ArgoCD Application.
app_state() {
  kubectl -n argocd get application "$1" -o jsonpath='{.status.sync.status} {.status.health.status}' 2>/dev/null || true
}
# wait_for_app <name> <expected state, a case pattern such as "Synced Healthy" or "OutOfSync *"> <seconds>
wait_for_app() {
  local state=""
  for _ in $(seq $(($3 / 5))); do
    state=$(app_state "$1")
    # shellcheck disable=SC2254 # $2 is a pattern on purpose
    case $state in $2) return 0 ;; esac
    sleep 5
  done
  echo "$1 is '$state', expected '$2'" >&2
  kubectl -n argocd get applications >&2 || true
  return 1
}
# place_order <base URL>: prints the new order's id, then waits for COMPLETED.
place_order() {
  local base=$1 order id status=""
  order=$(node_curl -sf -X POST -H 'Content-Type: application/json' -d '{"product_id": 1, "quantity": 2}' \
    "$base/api/orders") || fail "POST $base/api/orders failed"
  id=$(echo "$order" | sed -n 's/.*"id": *\([0-9][0-9]*\).*/\1/p')
  [ -n "$id" ] || fail "no order id in: $order"
  for _ in $(seq 30); do
    status=$(node_curl -sf "$base/api/orders/$id" | sed -n 's/.*"status": *"\([A-Z]*\)".*/\1/p')
    [ "$status" = "COMPLETED" ] && break
    sleep 1
  done
  [ "$status" = "COMPLETED" ] || fail "order $id via $base is $status, not COMPLETED"
  echo "$id"
}

for file in bootstrap/root-app.yaml bootstrap/argocd-values.yaml apps/traefik.yaml; do
  [ -f "$GITOPS_DIR/$file" ] || fail "$GITOPS_DIR/$file not found (set SHOPLITE_GITOPS_DIR)"
done

step "building the images (the three services, the test Git server, the lab machine's tools)"
for s in web catalog-api order-worker; do
  docker build -q --target runtime -t "shoplite/$s:local" "services/$s" >/dev/null
done
docker build -q -t shoplite/gitops-test-git -f scripts/tests/gitserver.Dockerfile scripts/tests >/dev/null
docker build -q -t shoplite/gitops-test-tools -f scripts/tests/tools.Dockerfile scripts/tests >/dev/null
for image in postgres:16-alpine redis:7.4-alpine "$HELM_IMAGE" "$K3S_IMAGE" "$YQ_IMAGE"; do
  docker image inspect "$image" >/dev/null 2>&1 || docker pull -q "$image" >/dev/null
done

step "publishing shoplite-app and shoplite-gitops as two repositories on the test Git server"
docker network create --subnet "$SUBNET" "$NET" >/dev/null
docker run -d --name "$GIT" --network "$NET" --ip "$GIT_IP" shoplite/gitops-test-git >/dev/null
# publish <folder> <repository name>: the folder's files as Git sees them (tracked and new,
# not ignored), committed on main in a bare repository inside the Git server's container.
# Not on the host's disk: there a cleaner of empty temp folders once deleted refs/ and broke
# the repositories in the middle of a run.
publish() {
  local src=$1 name=$2
  local tree="$WORK/$name"
  mkdir -p "$tree"
  (cd "$src" && git ls-files -z -co --exclude-standard | tar --null -T - -cf -) | tar -xf - -C "$tree"
  if [ "$name" = shoplite-gitops ]; then
    # Test only: the Applications read the test server instead of GitHub, and the image
    # tag is written the way CI writes it.
    find "$tree" -name '*.yaml' -exec sed -i -e "s|$APP_URL|http://$GIT_IP/shoplite-app.git|g" \
      -e "s|$GITOPS_URL|http://$GIT_IP/shoplite-gitops.git|g" {} +
    for env in dev prod; do
      yq '.image.registry = "" | .image.tag = "local"' <"$tree/envs/$env/values.yaml" >"$tree/values.tmp"
      mv "$tree/values.tmp" "$tree/envs/$env/values.yaml"
    done
    cp -r "$tree" "$WORK/gitops" # what bootstrap-cluster.sh reads: the lab machine's clone
  fi
  tar -cf - -C "$tree" . | docker exec -i "$GIT" sh -ec "
    mkdir /tmp/$name && tar -xf - -C /tmp/$name && cd /tmp/$name
    git init -q -b main && git add -A
    git -c user.name=rehearsal -c user.email=rehearsal@example.invalid commit -q -m snapshot
    git clone -q --bare /tmp/$name /srv/git/$name.git"
}
mkdir -p "$WORK/kube"
publish . shoplite-app
publish "$GITOPS_DIR" shoplite-gitops
grep -rh "repoURL: http://$GIT_IP" "$WORK/gitops" | sort | uniq -c | sed 's/^ */      /'

step "starting k3s ($K3S_IMAGE)"
# Kubernetes 1.35+ refuses cgroup v1, which Docker Desktop on WSL2's default kernel runs;
# the lab's EC2 nodes run cgroup v2 and need nothing.
KUBELET_ARGS=()
if [ "$(docker info --format '{{.CgroupVersion}}')" = "1" ]; then
  KUBELET_ARGS=(--kubelet-arg=fail-cgroupv1=false)
  echo "note: this Docker host runs cgroup v1; the test kubelet gets fail-cgroupv1=false"
fi
# k3s's data folder is a volume: containerd's overlayfs cannot sit on the container's own.
docker run -d --name "$NODE" --hostname "$NODE" --privileged --cgroupns=private --network "$NET" \
  --tmpfs /run --tmpfs /var/run -v /var/lib/rancher/k3s \
  "$K3S_IMAGE" server --disable=traefik "${KUBELET_ARGS[@]}" >/dev/null
for _ in $(seq 90); do
  kubectl get node "$NODE" --no-headers 2>/dev/null | grep -q ' Ready ' && break
  sleep 2
done
kubectl get node "$NODE" --no-headers | grep -q ' Ready ' || fail "k3s did not become Ready"
docker exec "$NODE" cat /etc/rancher/k3s/k3s.yaml >"$WORK/kube/config"
# grep -c reads all of curl's output (grep -q could stop early and break curl's pipe).
node_curl -sf "http://$GIT_IP/shoplite-gitops.git/info/refs?service=git-upload-pack" |
  grep -c refs/heads/main >/dev/null || fail "the test Git server does not answer from the cluster's network"
echo "ok    the test Git server answers from the cluster's network: http://$GIT_IP/<repository>.git"

step "loading the images into k3s (ShopLite, PostgreSQL, Redis, Traefik, ArgoCD)"
traefik_app() { yq "$1" <"$WORK/gitops/apps/traefik.yaml"; }
images="shoplite/web:local shoplite/catalog-api:local shoplite/order-worker:local postgres:16-alpine redis:7.4-alpine"
images="$images traefik:$(docker run --rm "$HELM_IMAGE" show chart "$(traefik_app .spec.source.chart)" \
  --repo "$(traefik_app .spec.source.repoURL)" --version "$(traefik_app .spec.source.targetRevision)" |
  sed -n 's/^appVersion: *//p')"
argocd_chart=$(sed -n 's/^ARGOCD_CHART_VERSION=\([^ ]*\).*/\1/p' scripts/bootstrap-cluster.sh)
images="$images $(docker run --rm -v "$WORK_HOST/gitops:/gitops:ro" "$HELM_IMAGE" template argocd argo-cd \
  --repo https://argoproj.github.io/argo-helm --version "$argocd_chart" -f /gitops/bootstrap/argocd-values.yaml |
  sed -n 's/^ *image: *"\{0,1\}\([^"]*\)"\{0,1\}$/\1/p' | sort -u | tr '\n' ' ')"
for image in $images; do
  docker image inspect "$image" >/dev/null 2>&1 || docker pull -q "$image" >/dev/null
  echo "      $image"
done
# shellcheck disable=SC2086 # one argument per image
docker save --platform linux/amd64 $images | docker exec -i "$NODE" ctr --namespace k8s.io images import - >/dev/null

step "running scripts/bootstrap-cluster.sh, as on the lab machine"
lab_machine bash scripts/bootstrap-cluster.sh || fail "scripts/bootstrap-cluster.sh failed"

step "running it again: it keeps both database Secrets"
secret_versions() {
  for ns in shoplite shoplite-dev; do
    kubectl -n "$ns" get secret shoplite-db -o jsonpath='{.metadata.resourceVersion} '
  done
}
before=$(secret_versions)
lab_machine bash scripts/bootstrap-cluster.sh >"$WORK/second-run.log" ||
  { cat "$WORK/second-run.log"; fail "the second run failed"; }
grep 'Secret shoplite-db' "$WORK/second-run.log" || true
[ "$(grep -c 'Secret shoplite-db exists, kept' "$WORK/second-run.log")" = 2 ] ||
  fail "the second run did not keep both Secrets"
[ "$(secret_versions)" = "$before" ] || fail "a database Secret changed on the second run"
echo "ok    second run: both Secrets unchanged (PostgreSQL keeps the password of its first start)"

step "ArgoCD builds the rest from Git on its own: root -> traefik (wave 0) -> shoplite-dev (wave 1)"
wait_for_app traefik "Synced Healthy" 600 || fail "traefik did not become Synced and Healthy"
echo "ok    traefik: Synced Healthy"
wait_for_app shoplite-dev "Synced Healthy" 600 || fail "shoplite-dev did not become Synced and Healthy"
echo "ok    shoplite-dev: Synced Healthy, with no one syncing it (automated)"
wait_for_app root "Synced *" 120 || fail "root is not Synced"
echo "ok    root: $(app_state root)"
# Without the health check for Applications (argocd-values.yaml), wave 1 would follow
# wave 0 at once, before Traefik's own sync had created its Middleware CRD. (Compared with
# the CRD, not with Traefik's pod: right after that sync ArgoCD may briefly report the
# traefik Application as Healthy while its diff waits for the new CRD's schema.)
crd_created=$(kubectl get crd middlewares.traefik.io -o jsonpath='{.metadata.creationTimestamp}')
traefik_ready=$(kubectl -n traefik get deployment traefik \
  -o jsonpath='{.status.conditions[?(@.type=="Available")].lastTransitionTime}')
for app in shoplite-dev shoplite-prod; do
  created=$(kubectl -n argocd get application "$app" -o jsonpath='{.metadata.creationTimestamp}')
  [[ ! "$created" < "$crd_created" ]] ||
    fail "$app was created at $created, before Traefik's Middleware CRD ($crd_created)"
done
echo "ok    sync waves: Traefik's CRDs at $crd_created, Traefik available at $traefik_ready, the ShopLite Applications created at $created"

step "prod waits for a manual sync"
wait_for_app shoplite-prod "OutOfSync *" 120 || fail "shoplite-prod is not OutOfSync"
[ -z "$(kubectl -n shoplite get deployments,statefulsets,services -o name)" ] ||
  fail "something was deployed to prod without a sync"
echo "ok    shoplite-prod: $(app_state shoplite-prod), nothing deployed in namespace shoplite"

step "ArgoCD at /argocd through Traefik's web entrypoint (NodePort 30080, the ALB's port 80)"
# ArgoCD writes the /argocd base into the page only for browsers (Accept: text/html).
page=$(node_curl -sf -H 'Accept: text/html' http://127.0.0.1:30080/argocd/) || fail "no answer at /argocd/"
echo "$page" | grep -q '<base href="/argocd/"' || { echo "$page" | head -n 20; fail "not ArgoCD's page at /argocd/"; }
code=$(node_curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:30080/argocd/api/v1/applications)
[ "$code" = "401" ] || fail "ArgoCD's API answered $code without a login"
password=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)
token=$(node_curl -sf -X POST -H 'Content-Type: application/json' \
  -d "{\"username\": \"admin\", \"password\": \"$password\"}" http://127.0.0.1:30080/argocd/api/v1/session |
  sed -n 's/.*"token": *"\([^"]*\)".*/\1/p')
[ -n "$token" ] || fail "admin could not log in"
echo "ok    the UI at /argocd/; the API answers 401 without a login; admin logs in with the cluster's password"
[ "$(kubectl -n argocd get configmap argocd-cm -o jsonpath='{.data.timeout\.reconciliation}')" = "60s" ] ||
  fail "ArgoCD does not look at Git every 60 s"
echo "ok    ArgoCD looks at Git every 60 s"

step "the manual prod sync, through ArgoCD's API (what the UI's Sync button sends)"
code=$(node_curl -s -o /dev/null -w '%{http_code}' -X POST -H "Authorization: Bearer $token" \
  -H 'Content-Type: application/json' -d '{}' http://127.0.0.1:30080/argocd/api/v1/applications/shoplite-prod/sync)
[ "$code" = "200" ] || fail "the sync request answered $code"
wait_for_app shoplite-prod "Synced Healthy" 600 || fail "shoplite-prod did not become Synced and Healthy"
echo "ok    shoplite-prod: Synced Healthy after the manual sync"
wait_for_app root "Synced Healthy" 300 || fail "root did not become Synced and Healthy"
echo "ok    root: Synced Healthy (every Application under it is healthy)"

step "the environments ArgoCD deployed take orders"
id=$(place_order http://127.0.0.1:30081)
echo "ok    dev (NodePort 30081, the ALB's port 8080): order $id COMPLETED"
id=$(place_order http://127.0.0.1:30080)
echo "ok    prod (NodePort 30080, the ALB's port 80): order $id COMPLETED"

step "self-heal (question 7d): a kubectl change in dev is put back; the same change in prod stays"
dev_replicas=$(kubectl -n shoplite-dev get deployment web -o jsonpath='{.spec.replicas}')
prod_replicas=$(kubectl -n shoplite get deployment web -o jsonpath='{.spec.replicas}')
kubectl -n shoplite-dev scale deployment web --replicas=$((dev_replicas + 2)) >/dev/null
kubectl -n shoplite scale deployment web --replicas=$((prod_replicas + 2)) >/dev/null
replicas=""
for _ in $(seq 24); do
  replicas=$(kubectl -n shoplite-dev get deployment web -o jsonpath='{.spec.replicas}')
  [ "$replicas" = "$dev_replicas" ] && break
  sleep 5
done
[ "$replicas" = "$dev_replicas" ] || fail "dev's web stayed at $replicas replicas: no self-heal"
echo "ok    dev: web scaled to $((dev_replicas + 2)) by hand, ArgoCD put it back to $dev_replicas (the value in Git)"
wait_for_app shoplite-prod "OutOfSync *" 120 || fail "shoplite-prod does not show the change"
[ "$(kubectl -n shoplite get deployment web -o jsonpath='{.spec.replicas}')" = "$((prod_replicas + 2))" ] ||
  fail "prod's web changed back although prod syncs only by hand"
echo "ok    prod: the change stays ($((prod_replicas + 2)) replicas) and shows as OutOfSync until someone syncs"

echo
kubectl -n argocd get applications
echo
echo "PASS: bootstrap, app of apps with sync waves, automated dev, manual prod, self-heal and /argocd work"
