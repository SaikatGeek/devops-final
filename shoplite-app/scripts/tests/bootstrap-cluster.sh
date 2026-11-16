#!/usr/bin/env bash
# Rehearses the GitOps bootstrap (scripts/bootstrap-cluster.sh) on a local k3s, without AWS
# and without GitHub:
#   1. build the three images, a test Git server (smart HTTP) and a tools image (bash,
#      kubectl and helm: what the lab machine needs); start k3s and load the images into it
#   2. publish the current shoplite-app and shoplite-gitops folders as two repositories on
#      the test server; in the gitops copy only, point the Applications at that server
#      instead of GitHub and write the image tag the way CI will (the images just built)
#   3. run scripts/bootstrap-cluster.sh against the cluster, then once more: the rerun
#      keeps both database Secrets and Grafana's admin Secret unchanged
#   4. check: root -> traefik, kube-prometheus-stack, loki, tempo and alloy -> shoplite-dev
#      become Synced and Healthy on their own; the ShopLite Applications (wave 1) appear
#      only after the CRDs of wave 0 (Traefik's, the Prometheus Operator's);
#      shoplite-prod stays OutOfSync, with nothing deployed, until it is synced by hand;
#      ArgoCD answers at /argocd on the web NodePort (the ALB's port 80) and its API wants
#      the admin login; the manual prod sync goes through that API, as the UI's Sync
#      button does; orders through both NodePorts reach COMPLETED; Prometheus scrapes
#      node-exporter, kube-state-metrics and catalog-api and order-worker of both
#      environments through their ServiceMonitors, with every target up, has the six
#      application metrics and trace_id exemplars on the latency histogram (question 6);
#      Grafana answers at /grafana, wants a login, and queries Prometheus; Loki has the
#      logs of every namespace with level and service labels (trace_id not a label); prod's
#      order can be followed through Grafana's data sources: its log line -> (the Loki
#      data source's trace_id link) -> its trace in Tempo, API -> queue -> worker ->
#      database -> (the Tempo data source's logs link) -> the worker's lines, and a
#      latency exemplar -> its trace; a kubectl change in dev is reverted by self-heal
#      (question 7d) while the same change in prod stays and shows as OutOfSync
#   5. remove everything again
# Needs Docker and internet (the charts and images of Traefik, ArgoCD and the monitoring
# stack). About 15 minutes. Run it from shoplite-app/, with shoplite-gitops next to it
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

for file in bootstrap/root-app.yaml bootstrap/argocd-values.yaml apps/traefik.yaml \
  apps/kube-prometheus-stack.yaml apps/loki.yaml apps/tempo.yaml apps/alloy.yaml; do
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
# node-exporter (question 6) mounts the node's / with HostToContainer propagation, so / must
# be a shared mount, as systemd makes it on a real node; in a container it is private.
docker exec "$NODE" mount --make-rshared /
docker exec "$NODE" cat /etc/rancher/k3s/k3s.yaml >"$WORK/kube/config"
# grep -c reads all of curl's output (grep -q could stop early and break curl's pipe).
node_curl -sf "http://$GIT_IP/shoplite-gitops.git/info/refs?service=git-upload-pack" |
  grep -c refs/heads/main >/dev/null || fail "the test Git server does not answer from the cluster's network"
echo "ok    the test Git server answers from the cluster's network: http://$GIT_IP/<repository>.git"

step "loading the images into k3s (ShopLite, PostgreSQL, Redis, Traefik, ArgoCD, the monitoring stack)"
traefik_app() { yq "$1" <"$WORK/gitops/apps/traefik.yaml"; }
# stack_images <Application>: the images of a monitoring chart (first source) rendered with
# its values file from shoplite-app (second source). Images pinned by digest are left to
# k3s to pull.
stack_images() {
  local app="$WORK/gitops/apps/$1.yaml"
  docker run --rm -v "$HOST_DIR:/app:ro" "$HELM_IMAGE" template "$1" \
    "$(yq '.spec.sources[0].chart' <"$app")" --repo "$(yq '.spec.sources[0].repoURL' <"$app")" \
    --version "$(yq '.spec.sources[0].targetRevision' <"$app")" --namespace monitoring \
    -f "$(yq '.spec.sources[0].helm.valueFiles[0]' <"$app" | sed 's|^[$]app/|/app/|')" |
    sed -n 's/^ *image: *"\{0,1\}\([^"@]*\)"\{0,1\}$/\1/p' | sort -u | tr '\n' ' '
}
images="shoplite/web:local shoplite/catalog-api:local shoplite/order-worker:local postgres:16-alpine redis:7.4-alpine"
images="$images traefik:$(docker run --rm "$HELM_IMAGE" show chart "$(traefik_app .spec.source.chart)" \
  --repo "$(traefik_app .spec.source.repoURL)" --version "$(traefik_app .spec.source.targetRevision)" |
  sed -n 's/^appVersion: *//p')"
argocd_chart=$(sed -n 's/^ARGOCD_CHART_VERSION=\([^ ]*\).*/\1/p' scripts/bootstrap-cluster.sh)
images="$images $(docker run --rm -v "$WORK_HOST/gitops:/gitops:ro" "$HELM_IMAGE" template argocd argo-cd \
  --repo https://argoproj.github.io/argo-helm --version "$argocd_chart" -f /gitops/bootstrap/argocd-values.yaml |
  sed -n 's/^ *image: *"\{0,1\}\([^"]*\)"\{0,1\}$/\1/p' | sort -u | tr '\n' ' ')"
for app in kube-prometheus-stack loki tempo alloy; do
  images="$images $(stack_images "$app")"
done
for image in $images; do
  docker image inspect "$image" >/dev/null 2>&1 || docker pull -q "$image" >/dev/null
  echo "      $image"
done
# shellcheck disable=SC2086 # one argument per image
docker save --platform linux/amd64 $images | docker exec -i "$NODE" ctr --namespace k8s.io images import - >/dev/null

step "running scripts/bootstrap-cluster.sh, as on the lab machine"
lab_machine bash scripts/bootstrap-cluster.sh || fail "scripts/bootstrap-cluster.sh failed"

step "running it again: it keeps the database Secrets and Grafana's admin Secret"
secret_versions() {
  for ns in shoplite shoplite-dev; do
    kubectl -n "$ns" get secret shoplite-db -o jsonpath='{.metadata.resourceVersion} '
  done
  kubectl -n monitoring get secret grafana-admin -o jsonpath='{.metadata.resourceVersion}'
}
before=$(secret_versions)
lab_machine bash scripts/bootstrap-cluster.sh >"$WORK/second-run.log" ||
  { cat "$WORK/second-run.log"; fail "the second run failed"; }
grep 'Secret ' "$WORK/second-run.log" || true
[ "$(grep -c -E 'Secret (shoplite-db|grafana-admin) exists, kept' "$WORK/second-run.log")" = 3 ] ||
  fail "the second run did not keep all three Secrets"
[ "$(secret_versions)" = "$before" ] || fail "a Secret changed on the second run"
echo "ok    second run: the three Secrets unchanged (PostgreSQL and Grafana keep the password of their first start)"

step "ArgoCD builds the rest from Git on its own: root -> traefik, the monitoring stack (wave 0) -> shoplite-dev (wave 1)"
wait_for_app traefik "Synced Healthy" 600 || fail "traefik did not become Synced and Healthy"
echo "ok    traefik: Synced Healthy"
wait_for_app kube-prometheus-stack "Synced Healthy" 900 || fail "kube-prometheus-stack did not become Synced and Healthy"
echo "ok    kube-prometheus-stack: Synced Healthy"
for app in loki tempo alloy; do
  wait_for_app "$app" "Synced Healthy" 600 || fail "$app did not become Synced and Healthy"
  echo "ok    $app: Synced Healthy"
done
wait_for_app shoplite-dev "Synced Healthy" 600 || fail "shoplite-dev did not become Synced and Healthy"
echo "ok    shoplite-dev: Synced Healthy, with no one syncing it (automated)"
wait_for_app root "Synced *" 120 || fail "root is not Synced"
echo "ok    root: $(app_state root)"
# Without the health check for Applications (argocd-values.yaml), wave 1 would follow
# wave 0 at once, before Traefik's own sync had created its Middleware CRD. (Compared with
# the CRD, not with Traefik's pod: right after that sync ArgoCD may briefly report the
# traefik Application as Healthy while its diff waits for the new CRD's schema.)
crd_created=$(kubectl get crd middlewares.traefik.io -o jsonpath='{.metadata.creationTimestamp}')
sm_crd_created=$(kubectl get crd servicemonitors.monitoring.coreos.com -o jsonpath='{.metadata.creationTimestamp}')
traefik_ready=$(kubectl -n traefik get deployment traefik \
  -o jsonpath='{.status.conditions[?(@.type=="Available")].lastTransitionTime}')
for app in shoplite-dev shoplite-prod; do
  created=$(kubectl -n argocd get application "$app" -o jsonpath='{.metadata.creationTimestamp}')
  [[ ! "$created" < "$crd_created" ]] ||
    fail "$app was created at $created, before Traefik's Middleware CRD ($crd_created)"
  [[ ! "$created" < "$sm_crd_created" ]] ||
    fail "$app was created at $created, before the ServiceMonitor CRD ($sm_crd_created)"
done
echo "ok    sync waves: Traefik's CRDs at $crd_created, the ServiceMonitor CRD at $sm_crd_created, Traefik available at $traefik_ready, the ShopLite Applications created at $created"

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
prod_order=$(place_order http://127.0.0.1:30080)
echo "ok    prod (NodePort 30080, the ALB's port 80): order $prod_order COMPLETED"

step "metrics (question 6.1): Prometheus scrapes the nodes, the cluster's state and both ShopLite environments"
prom_ip=$(kubectl -n monitoring get service kube-prometheus-stack-prometheus -o jsonpath='{.spec.clusterIP}')
# prom_query <PromQL>: one "<label>=<value>,... <sample value>" line per series of the
# result, asked from the node's own network (the Service's cluster IP).
prom_query() {
  node_curl -sf --data-urlencode "query=$1" "http://$prom_ip:9090/api/v1/query" |
    yq -p json '.data.result[] | ((.metric | to_entries | map(.key + "=" + .value) | join(",")) + " " + .value[1])'
}
wanted="job=catalog-api,namespace=shoplite job=catalog-api,namespace=shoplite-dev job=order-worker,namespace=shoplite
  job=order-worker,namespace=shoplite-dev job=kube-state-metrics,namespace=monitoring job=node-exporter,namespace=monitoring"
up="" missing=$wanted
for _ in $(seq 36); do
  up=$(prom_query 'count by (job, namespace) (up == 1)' || true)
  missing=""
  for want in $wanted; do grep -q "^$want " <<<"$up" || missing="$missing $want"; done
  [ -z "$missing" ] && break
  sleep 5
done
[ -z "$missing" ] || { echo "$up"; fail "Prometheus does not scrape:$missing"; }
down=$(prom_query 'up == 0')
[ -z "$down" ] || { echo "$down"; fail "some targets are down"; }
echo "ok    every target is up, among them node-exporter, kube-state-metrics, and catalog-api and order-worker of both environments (targets per job):"
while read -r line; do echo "        $line"; done <<<"$up"
names=$(prom_query 'count by (__name__) ({namespace="shoplite", __name__=~"http_requests_total|http_request_duration_seconds_bucket|orders_created_total|orders_processed_total|order_queue_depth|order_processing_seconds_bucket"})' |
  cut -d' ' -f1 | sed 's/^__name__=//' | LC_ALL=C sort | tr '\n' ' ')
[ "$names" = "http_request_duration_seconds_bucket http_requests_total order_processing_seconds_bucket order_queue_depth orders_created_total orders_processed_total " ] ||
  fail "prod's application metrics in Prometheus: $names"
echo "ok    the six application metrics of prod are in Prometheus: $names"
# Exemplars (question 6.4): the trace_id catalog-api attached to its latency observations.
exemplar=""
for _ in $(seq 18); do
  exemplar=$(node_curl -sf --data-urlencode 'query=http_request_duration_seconds_bucket{namespace="shoplite"}' \
    --data-urlencode "start=$(($(date +%s) - 1800))" --data-urlencode "end=$(date +%s)" \
    "http://$prom_ip:9090/api/v1/query_exemplars" | yq -p json '[.data[].exemplars[].labels.trace_id] | .[0] // ""' || true)
  [[ $exemplar =~ ^[0-9a-f]{32}$ ]] && break
  sleep 5
done
[[ $exemplar =~ ^[0-9a-f]{32}$ ]] || fail "no exemplar with a trace_id on prod's http_request_duration_seconds"
echo "ok    exemplars on http_request_duration_seconds, e.g. trace_id $exemplar"

step "Grafana at /grafana through Traefik's web entrypoint (NodePort 30080, the ALB's port 80)"
code=$(node_curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:30080/grafana/api/user)
[ "$code" = 401 ] || fail "Grafana's API answered $code without a login"
grafana_password=$(kubectl -n monitoring get secret grafana-admin -o jsonpath='{.data.admin-password}' | base64 -d)
node_curl -sf -u "admin:$grafana_password" http://127.0.0.1:30080/grafana/api/user | grep -c '"login":"admin"' >/dev/null ||
  fail "admin could not log in to Grafana with the cluster's password"
node_curl -sf -u "admin:$grafana_password" --data-urlencode 'query=count(up{job="catalog-api"})' \
  http://127.0.0.1:30080/grafana/api/datasources/proxy/uid/prometheus/api/v1/query | grep -c '"status":"success"' >/dev/null ||
  fail "Grafana's Prometheus data source (uid prometheus) does not answer"
node_curl -sf http://127.0.0.1:30080/grafana/login | grep -c '<base href="/grafana/"' >/dev/null ||
  fail "Grafana's page is not served under /grafana/"
echo "ok    Grafana's page under /grafana/; its API answers 401 without a login; admin logs in with the cluster's password; it queries Prometheus (data source uid prometheus)"

step "logs and traces (questions 6.1 and 6.4): Alloy -> Loki, OTLP -> Tempo, and Grafana's links between them"
# grafana <API path> [curl options]: Grafana's API as admin, through Traefik's web entrypoint.
grafana() {
  local path=$1
  shift
  node_curl -sf -u "admin:$grafana_password" "$@" "http://127.0.0.1:30080/grafana/api/$path"
}
# loki <API path> [curl options]: Loki's API through Grafana's data source uid loki.
loki() {
  local path=$1
  shift
  grafana "datasources/proxy/uid/loki/loki/api/v1/$path" "$@"
}
# loki_lines <LogQL>: the matching log lines of the last hour, one per line.
loki_lines() {
  loki query_range -G --data-urlencode "query=$1" --data-urlencode limit=100 | yq -p json '.data.result[].values[][1]'
}
# loki_values <label>: the label's values in Loki, on one line.
loki_values() { loki "label/$1/values" | yq -p json '.data | join(" ")'; }
# tempo_trace <trace id>: the trace from Tempo's API through Grafana's data source uid tempo;
# waits up to two minutes for its spans.
tempo_trace() {
  local trace=""
  for _ in $(seq 24); do
    trace=$(grafana "datasources/proxy/uid/tempo/api/v2/traces/$1" || true)
    [ -n "$trace" ] && [ "$(yq -p json '[.trace.resourceSpans[].scopeSpans[].spans[]] | length' <<<"$trace")" -gt 0 ] && break
    sleep 5
  done
  echo "$trace"
}
# spans <trace>: one "<service> <span kind> <span name>" line per span.
spans() {
  # shellcheck disable=SC2016 # $service is yq's variable
  yq -p json '.trace.resourceSpans[] | (.resource.attributes[] | select(.key == "service.name") | .value.stringValue) as $service | .scopeSpans[].spans[] | $service + " " + (.kind | sub("SPAN_KIND_"; "")) + " " + .name' <<<"$1"
}

# web logs real requests only (its /healthz probes are not logged), and the orders went to
# /api, which Traefik sends straight to catalog-api: open each environment's page once.
for port in 30080 30081; do
  node_curl -sf -o /dev/null "http://127.0.0.1:$port/" || fail "no page on NodePort $port"
done
# Every pod's logs: Alloy runs on every node and reads the logs of all namespaces; the JSON
# lines of the three ShopLite services get their service label.
missing=""
for _ in $(seq 24); do
  namespaces=$(loki_values namespace || true)
  services=$(loki_values service || true)
  missing=""
  for ns in argocd kube-system monitoring shoplite shoplite-dev traefik; do
    [[ " $namespaces " == *" $ns "* ]] || missing="$missing namespace=$ns"
  done
  for service in web catalog-api order-worker; do
    [[ " $services " == *" $service "* ]] || missing="$missing service=$service"
  done
  [ -z "$missing" ] && break
  sleep 5
done
[ -z "$missing" ] || fail "Loki has no logs with:$missing (namespaces: $namespaces; services: $services)"
echo "ok    Loki has the logs of every namespace: $namespaces"
# JSON parsing: level and service are labels; trace_id is not.
labels=$(loki labels | yq -p json '.data | join(" ")')
for label in namespace pod container level service; do
  [[ " $labels " == *" $label "* ]] || fail "Loki has no label $label (labels: $labels)"
done
[[ " $labels " != *" trace_id "* ]] || fail "trace_id is a Loki label"
echo "ok    Alloy parses the JSON lines: labels $labels; service values: $services; trace_id stays in the line"

# Log -> trace: catalog-api's line for prod's order, then the Loki data source's link.
line=""
for _ in $(seq 24); do
  line=$(loki_lines "{namespace=\"shoplite\", service=\"catalog-api\"} | json | message=\"order created\" | order_id=\"$prod_order\"" | head -n 1 || true)
  [ -n "$line" ] && break
  sleep 5
done
[ -n "$line" ] || fail "Loki has no 'order created' line for prod's order $prod_order"
echo "ok    Loki: catalog-api's line for prod's order $prod_order: $line"
derived=$(grafana datasources/uid/loki | yq -p json '.jsonData.derivedFields[0] | .datasourceUid + " " + .url')
# shellcheck disable=SC2016 # the literal URL Grafana fills in, not a shell expansion
[ "$derived" = 'tempo ${__value.raw}' ] || fail "the Loki data source's trace link is '$derived'"
regex=$(grafana datasources/uid/loki | yq -p json '.jsonData.derivedFields[0].matcherRegex')
trace_id=$(grep -oE "$regex" <<<"$line" | sed -E "s/$regex/\1/" || true)
[[ $trace_id =~ ^[0-9a-f]{32}$ ]] || fail "the Loki data source's regex $regex finds no trace_id in the line"
echo "ok    the Loki data source's link (regex $regex, data source uid tempo) takes the line to trace $trace_id"

# The order's trace in Tempo: API -> queue -> worker -> database.
trace=$(tempo_trace "$trace_id")
order_spans=$(spans "$trace" | LC_ALL=C sort)
for want in "catalog-api SERVER POST /orders" "catalog-api CLIENT INSERT orders" \
  "catalog-api PRODUCER send orders:pending" "order-worker CONSUMER process orders:pending" \
  "order-worker CLIENT UPDATE orders"; do
  grep -qxF "$want" <<<"$order_spans" || { echo "$order_spans"; fail "trace $trace_id has no span '$want'"; }
done
producer=$(yq -p json '.trace.resourceSpans[].scopeSpans[].spans[] | select(.kind == "SPAN_KIND_PRODUCER") | .spanId' <<<"$trace")
consumer_parent=$(yq -p json '.trace.resourceSpans[].scopeSpans[].spans[] | select(.kind == "SPAN_KIND_CONSUMER") | .parentSpanId' <<<"$trace")
[[ -n $producer && $producer == "$consumer_parent" ]] ||
  fail "order-worker's span is not a child of catalog-api's queue span: the context did not cross the queue"
environments=$(yq -p json '[.trace.resourceSpans[].resource.attributes[] | select(.key == "deployment.environment") | .value.stringValue] | unique | join(" ")' <<<"$trace")
[ "$environments" = prod ] || fail "trace $trace_id comes from environment(s) '$environments', not prod"
echo "ok    Tempo: prod's order in one trace, the worker's span a child of the API's queue span:"
while read -r span; do echo "        $span"; done <<<"$order_spans"

# Trace -> logs: the Tempo data source's link, and the Loki query it builds for a span of
# order-worker: {service="order-worker"} |= "<trace id>".
links=$(grafana datasources/uid/tempo | yq -p json '.jsonData.tracesToLogsV2 | .datasourceUid + " " + .tags[0].key + "=" + .tags[0].value + " " + (.filterByTraceID | tostring)')
[ "$links" = "loki service.name=service true" ] || fail "the Tempo data source's logs link is '$links'"
worker_lines=$(loki_lines "{service=\"order-worker\"} |= \"$trace_id\"")
grep -q '"message": "order completed"' <<<"$worker_lines" ||
  { echo "$worker_lines"; fail "the trace's logs link finds no 'order completed' line of order-worker"; }
echo "ok    the Tempo data source's link (data source uid loki, service.name -> service, the trace's id) finds the worker's lines: $(grep -c . <<<"$worker_lines") lines"

# Exemplar -> trace: the Prometheus data source's link, and the exemplar's trace in Tempo.
exemplar_link=$(grafana datasources/uid/prometheus | yq -p json '.jsonData.exemplarTraceIdDestinations[0] | .name + " " + .datasourceUid')
[ "$exemplar_link" = "trace_id tempo" ] || fail "the Prometheus data source's exemplar link is '$exemplar_link'"
grep -q '^catalog-api SERVER ' <<<"$(spans "$(tempo_trace "$exemplar")")" ||
  fail "the exemplar's trace $exemplar is not in Tempo"
echo "ok    the Prometheus data source links an exemplar's trace_id to Tempo, where exemplar $exemplar's trace is"

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
echo "PASS: bootstrap, app of apps with sync waves, automated dev, manual prod, the metrics stack (targets, metrics, exemplars, Grafana at /grafana), logs and traces linked in Grafana, self-heal and /argocd work"
