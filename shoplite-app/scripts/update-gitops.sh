#!/usr/bin/env bash
# Commits a new image tag to shoplite-gitops (question 7a): writes an environment's image
# registry and tag into envs/<env>/values.yaml of a shoplite-gitops checkout, commits and
# pushes. ArgoCD then deploys from Git; nothing here touches the cluster. The main pipeline
# (.github/workflows/main.yml) runs it for dev, right after pushing the images to ECR; the
# promote workflow (.github/workflows/promote.yml) runs it for prod with dev's image:
#   scripts/update-gitops.sh <shoplite-gitops checkout> <dev|prod> <registry> <tag>
# Each attempt starts again from the newest main, so a commit pushed in the meantime is kept;
# after three failed pushes it gives up. Writing the tag that is already there commits
# nothing. Needs git and yq (mikefarah, v4), both installed on GitHub's runners.
set -euo pipefail

fail() { echo "update-gitops: $*" >&2; exit 1; }

[ $# -eq 4 ] || fail "usage: $0 <shoplite-gitops checkout> <dev|prod> <registry> <tag>"
dir=$1 env=$2 registry=$3 tag=$4
case $env in dev | prod) ;; *) fail "unknown environment '$env' (dev or prod)" ;; esac
# Both end up in image names: a registry host (no scheme, no path) and a Docker tag.
[[ $registry =~ ^[a-z0-9]([a-z0-9.-]*[a-z0-9])?(:[0-9]+)?$ ]] || fail "not a registry host: '$registry'"
[[ $tag =~ ^[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}$ ]] || fail "not an image tag: '$tag'"

values=envs/$env/values.yaml
cd "$dir"
[ -f "$values" ] || fail "$dir/$values not found"

message=(-m "$env: images $tag")
if [ -n "${GITHUB_RUN_ID:-}" ]; then
  run=$GITHUB_SERVER_URL/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID
  case $env in
    dev) message+=(-m "Built and pushed by $run from $GITHUB_REPOSITORY@$GITHUB_SHA.") ;;
    prod) message+=(-m "Promoted from dev by $run.") ;;
  esac
fi

for attempt in 1 2 3; do
  # An explicit refspec: actions/checkout makes a shallow clone of just one branch.
  git fetch -q origin +refs/heads/main:refs/remotes/origin/main
  git reset -q --hard refs/remotes/origin/main
  # strenv() keeps the tag a string: yq quotes a short SHA such as 0123456 or 1e23456, which
  # would otherwise be read as a number.
  REGISTRY=$registry TAG=$tag yq -i '.image.registry = strenv(REGISTRY) | .image.tag = strenv(TAG)' "$values"
  if git diff --quiet -- "$values"; then
    echo "$env already has $registry/shoplite/<service>:$tag; nothing to commit"
    exit 0
  fi
  git -c user.name='github-actions[bot]' -c user.email='41898282+github-actions[bot]@users.noreply.github.com' \
    commit -q "${message[@]}" -- "$values"
  if git push -q origin HEAD:main; then
    echo "$env now has $registry/shoplite/<service>:$tag (shoplite-gitops $(git rev-parse --short HEAD))"
    exit 0
  fi
  echo "update-gitops: push failed (attempt $attempt of 3); trying again from the newest main" >&2
  sleep $((attempt * 5))
done
fail "could not push to shoplite-gitops"
