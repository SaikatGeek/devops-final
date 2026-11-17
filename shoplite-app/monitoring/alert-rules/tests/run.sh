#!/usr/bin/env bash
# Unit tests of ShopLite's alerts (question 6.5), with the promtool of the Prometheus that
# kube-prometheus-stack runs (v3.15.1):
#   1. the five alerts are exactly the question's, each with its severity, and a runbook_url
#      to its runbook, which exists in monitoring/runbooks/
#   2. promtool check rules: the PrometheusRule's rules are valid
#   3. promtool test rules (shoplite-alerts.test.yaml): each alert fires, with its labels and
#      annotations, only once its condition has held for its time
# Needs Docker. About 10 seconds. Run it from shoplite-app/:
#   bash monitoring/alert-rules/tests/run.sh
set -euo pipefail
cd "$(dirname "$0")/../../.."

export MSYS_NO_PATHCONV=1 # Git Bash on Windows: leave container paths alone
PROMETHEUS_IMAGE=quay.io/prometheus/prometheus:v3.15.1
YQ_IMAGE=mikefarah/yq:4.54.1
RULES=monitoring/alert-rules/shoplite-alerts.yaml
RUNBOOKS=https://github.com/SaikatGeek/shoplite-app/blob/main/monitoring/runbooks
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
yq() { docker run --rm -i "$YQ_IMAGE" "$@"; }

echo "==> the question's five alerts, their severities and runbooks"
alerts=$(yq '.spec.groups[].rules[] | .alert + " " + .labels.severity + " " + .annotations.runbook_url' <"$RULES")
expected="HighErrorRate critical
HighLatency warning
QueueBacklog warning
PodCrashLooping critical
NodeDiskFilling warning"
[ "$(cut -d' ' -f1,2 <<<"$alerts")" = "$expected" ] ||
  { echo "$alerts"; fail "the alerts or their severities differ from question 6.5's table"; }
while read -r alert severity url; do
  [ "$url" = "$RUNBOOKS/$alert.md" ] || fail "$alert's runbook_url is $url"
  [ -s "monitoring/runbooks/$alert.md" ] || fail "monitoring/runbooks/$alert.md is missing"
  echo "ok    $alert ($severity): $url"
done <<<"$alerts"

echo "==> promtool check rules and test rules ($PROMETHEUS_IMAGE)"
# promtool reads plain rule files: the PrometheusRule's spec.
yq '.spec' <"$RULES" >"$WORK/shoplite-alerts.rules.yaml"
cp monitoring/alert-rules/tests/shoplite-alerts.test.yaml "$WORK/"
WORK_HOST=$(cd "$WORK" && (pwd -W 2>/dev/null || pwd))
promtool() { docker run --rm -v "$WORK_HOST:/t:ro" -w /t --entrypoint promtool "$PROMETHEUS_IMAGE" "$@"; }
promtool check rules shoplite-alerts.rules.yaml
promtool test rules shoplite-alerts.test.yaml

echo
echo "PASS: the five alerts, their severities and runbooks, and promtool's unit tests"
