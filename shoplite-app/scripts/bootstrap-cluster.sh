#!/usr/bin/env bash
# Prepares a new ShopLite cluster for GitOps (PLAN phase 6). Run it once per cluster, from
# shoplite-app/, with kubectl pointing at the cluster (in the lab: the kubeconfig Ansible
# fetched, through the kubectl_tunnel SSM port forward) and helm installed:
#   1. namespaces shoplite (prod) and shoplite-dev (dev)
#   2. the database Secret shoplite-db in each, with a random password, unless it exists
#      already: PostgreSQL fixes the password on its first start, so a rerun keeps it
#   3. namespace monitoring and Grafana's admin Secret grafana-admin, with a random password,
#      unless it exists already (Grafana too keeps the password of its first start); and
#      Alertmanager's Secret alertmanager-slack with the Slack incoming webhook's URL, from
#      SLACK_WEBHOOK_URL (needed on the first run; a rerun without it keeps the Secret)
#   4. ArgoCD from its pinned Helm chart, with shoplite-gitops/bootstrap/argocd-values.yaml
#   5. shoplite-gitops/bootstrap/root-app.yaml; from then on ArgoCD builds the rest from Git
# Nothing secret goes to Git or to the screen. Safe to run again.
#
# shoplite-gitops must be next to shoplite-app (as in devops-final, or both repositories
# cloned side by side); SHOPLITE_GITOPS_DIR overrides the path.
set -euo pipefail
cd "$(dirname "$0")/.."

GITOPS_DIR=${SHOPLITE_GITOPS_DIR:-../shoplite-gitops}
ARGOCD_CHART_REPO=https://argoproj.github.io/argo-helm
ARGOCD_CHART_VERSION=10.11.6 # ArgoCD v3.5.6
NAMESPACES="shoplite shoplite-dev"

step() { echo "==> $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

for tool in kubectl helm; do
  command -v "$tool" >/dev/null || fail "$tool is not installed"
done
for file in bootstrap/argocd-values.yaml bootstrap/root-app.yaml; do
  [ -f "$GITOPS_DIR/$file" ] || fail "$GITOPS_DIR/$file not found (set SHOPLITE_GITOPS_DIR)"
done
kubectl get nodes >/dev/null || fail "kubectl cannot reach the cluster (kubeconfig, SSM tunnel?)"
# The alerts' Slack webhook (question 6), checked before anything changes.
if [ -n "${SLACK_WEBHOOK_URL:-}" ]; then
  case $SLACK_WEBHOOK_URL in
    https://* | http://*) ;;
    *) fail "SLACK_WEBHOOK_URL is not a URL" ;;
  esac
elif ! kubectl -n monitoring get secret alertmanager-slack >/dev/null 2>&1; then
  fail "set SLACK_WEBHOOK_URL to the Slack incoming webhook for the alerts (it goes into the cluster's Secret alertmanager-slack, never into Git)"
fi

step "namespaces and database Secrets"
for ns in $NAMESPACES; do
  kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
  if kubectl -n "$ns" get secret shoplite-db >/dev/null 2>&1; then
    echo "$ns: Secret shoplite-db exists, kept"
  else
    kubectl -n "$ns" create secret generic shoplite-db \
      --from-literal=POSTGRES_USER=shoplite \
      --from-literal=POSTGRES_PASSWORD="$(head -c 24 /dev/urandom | base64 | tr -d '+/=')" >/dev/null
    echo "$ns: Secret shoplite-db created (random password)"
  fi
done

step "namespace monitoring and Grafana's admin Secret"
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f - >/dev/null
if kubectl -n monitoring get secret grafana-admin >/dev/null 2>&1; then
  echo "monitoring: Secret grafana-admin exists, kept"
else
  kubectl -n monitoring create secret generic grafana-admin --from-literal=admin-user=admin \
    --from-literal=admin-password="$(head -c 24 /dev/urandom | base64 | tr -d '+/=')" >/dev/null
  echo "monitoring: Secret grafana-admin created (random password)"
fi
if [ -n "${SLACK_WEBHOOK_URL:-}" ]; then
  kubectl -n monitoring create secret generic alertmanager-slack --from-literal=webhook-url="$SLACK_WEBHOOK_URL" \
    --dry-run=client -o yaml | kubectl apply -f - >/dev/null
  echo "monitoring: Secret alertmanager-slack set from SLACK_WEBHOOK_URL"
else
  echo "monitoring: Secret alertmanager-slack exists, kept"
fi

step "ArgoCD (chart $ARGOCD_CHART_VERSION)"
helm upgrade --install argocd argo-cd --repo "$ARGOCD_CHART_REPO" --version "$ARGOCD_CHART_VERSION" \
  --namespace argocd --create-namespace -f "$GITOPS_DIR/bootstrap/argocd-values.yaml" \
  --wait --timeout 10m >/dev/null
kubectl -n argocd get deployments

step "the root Application: from here on ArgoCD builds everything from Git"
kubectl apply -f "$GITOPS_DIR/bootstrap/root-app.yaml"

echo
echo "ArgoCD: http://<ALB DNS name>/argocd (terraform output app_urls), user admin. Password:"
echo "  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo"
echo "Grafana: http://<ALB DNS name>/grafana, user admin. Password:"
echo "  kubectl -n monitoring get secret grafana-admin -o jsonpath='{.data.admin-password}' | base64 -d; echo"
