#!/usr/bin/env bash
# The checks of the main and pull-request pipelines (question 7a and 7b), one stage per call,
# so GitHub Actions (.github/workflows/) and a run on any machine with Docker do exactly the
# same:
#   bash scripts/ci.sh lint          Hadolint on the three Dockerfiles, and helm lint --strict
#                                    of the chart with dev's and with prod's values
#   bash scripts/ci.sh test          the unit tests: each service's Docker test stage, and
#                                    the alerts' promtool tests
#   bash scripts/ci.sh build <tag>   the three runtime images, shoplite/<service>:<tag>
#   bash scripts/ci.sh scan <tag>    Trivy on those images; fails if any has a CRITICAL
#                                    vulnerability
# Every tool runs from an image pinned by digest (a tag can be moved; trivy-action's tags were
# hijacked in March 2026). Run it from shoplite-app/.
set -euo pipefail
cd "$(dirname "$0")/.."

export MSYS_NO_PATHCONV=1 # Git Bash on Windows: leave container paths alone
HOST_DIR=$(pwd -W 2>/dev/null || pwd)
SERVICES="web catalog-api order-worker"
HADOLINT_IMAGE=hadolint/hadolint:v2.15.1@sha256:32dac94127fd60b7b7e3fbfc65e1383b9b5e25c9bfd7b8536de7a539fe68a12d
HELM_IMAGE=alpine/helm:4.3.1@sha256:e3f8d5c462d75470fbb1fce79ad5c20063657096d1f98c0fcea869e2600e2e5e
TRIVY_IMAGE=aquasec/trivy:0.76.1@sha256:790fd66d1697395d8693d1acaa1ea702406a20f109b6fc7bac8db623eca6c06c

step() { echo "==> $*"; }
usage() {
  echo "usage: bash scripts/ci.sh lint | test | build <tag> | scan <tag>" >&2
  exit 2
}

case ${1:-} in
  lint)
    for service in $SERVICES; do
      step "Hadolint: services/$service/Dockerfile"
      docker run --rm -i "$HADOLINT_IMAGE" hadolint - <"services/$service/Dockerfile"
    done
    for env in dev prod; do
      step "helm lint --strict: helm/shoplite with values-$env.yaml"
      docker run --rm -v "$HOST_DIR/helm:/helm:ro" -w /helm "$HELM_IMAGE" \
        lint shoplite --strict -f "shoplite/values-$env.yaml"
    done
    ;;
  test)
    for service in $SERVICES; do
      step "unit tests: $service (its Docker test stage)"
      docker build -q --target test -t "shoplite/$service:test" "services/$service" >/dev/null
      docker run --rm "shoplite/$service:test"
    done
    step "unit tests: the alerts (promtool)"
    bash monitoring/alert-rules/tests/run.sh
    ;;
  build)
    [ -n "${2:-}" ] || usage
    for service in $SERVICES; do
      step "build: shoplite/$service:$2"
      docker build --target runtime -t "shoplite/$service:$2" "services/$service"
    done
    ;;
  scan)
    [ -n "${2:-}" ] || usage
    # Every image is scanned before the stage fails, so one run lists all the findings.
    failed=""
    for service in $SERVICES; do
      step "Trivy: shoplite/$service:$2 (stops on CRITICAL)"
      docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v shoplite-trivy-cache:/root/.cache/trivy \
        "$TRIVY_IMAGE" image --scanners vuln --severity CRITICAL --exit-code 1 --no-progress "shoplite/$service:$2" ||
        failed="$failed $service"
    done
    if [ -n "$failed" ]; then
      echo "::error::CRITICAL vulnerabilities in:$failed"
      exit 1
    fi
    ;;
  *) usage ;;
esac
