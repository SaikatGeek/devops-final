#!/usr/bin/env bash
# Rehearses the main pipeline (.github/workflows/main.yml) as far as it runs without GitHub
# and AWS (the real run needs the split repositories and a lab session):
#   1. actionlint checks the workflow and runs shellcheck on its run steps; shellcheck checks
#      the scripts
#   2. the workflow runs on a push to main and from its "Run workflow" button, nothing else;
#      every action is pinned to the commit of the release its comment names, and gets only
#      inputs that this commit's action.yml declares (actionlint does not know the newest
#      releases); every step output the workflow reads exists
#   3. scripts/update-gitops.sh, run the way the pipeline runs it, against a copy of
#      shoplite-gitops (a bare repository standing in for GitHub, and clones): it writes
#      dev's registry and tag in one commit and pushes it, prod untouched; a rerun with the
#      same tag commits nothing; a rejected push is retried from the newest main, keeping a
#      commit pushed in the meantime; SHAs that look like numbers stay strings; bad input
#      is refused
#   4. the chart, with the values CI wrote (layered as the dev Application layers them),
#      renders the ECR images with the new tag
# Needs Docker and internet (images, and the actions' repositories on GitHub). About a
# minute. Run it from shoplite-app/, with shoplite-gitops next to it (SHOPLITE_GITOPS_DIR
# overrides the path):
#   bash scripts/tests/pipeline.sh
set -euo pipefail
cd "$(dirname "$0")/../.."

export MSYS_NO_PATHCONV=1 # Git Bash on Windows: leave container paths alone
HOST_DIR=$(pwd -W 2>/dev/null || pwd)
GITOPS_DIR=${SHOPLITE_GITOPS_DIR:-../shoplite-gitops}
ACTIONLINT_IMAGE=rhysd/actionlint:1.7.12
HELM_IMAGE=alpine/helm:4.3.1
RUNNER=shoplite-pipeline-test
WORKFLOW=.github/workflows/main.yml
# What ECR's login step gives the pipeline (any account and region would do).
REGISTRY=123456789012.dkr.ecr.ap-southeast-1.amazonaws.com

remove_runner() { docker rm -f "$RUNNER" >/dev/null 2>&1 || true; }
trap remove_runner EXIT
remove_runner # leftovers of an interrupted earlier run

step() { echo "==> $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }
# on_runner: runs the bash script on stdin in the stand-in for GitHub's runner.
on_runner() { docker exec -i -e REGISTRY="$REGISTRY" "$RUNNER" bash -euo pipefail -s; }

[ -f "$GITOPS_DIR/envs/dev/values.yaml" ] || fail "$GITOPS_DIR/envs/dev/values.yaml not found (set SHOPLITE_GITOPS_DIR)"

step "actionlint on the workflow (with shellcheck on its run steps), shellcheck on the scripts"
docker run --rm -v "$HOST_DIR:/repo:ro" -w /repo "$ACTIONLINT_IMAGE" -no-color "$WORKFLOW" ||
  fail "actionlint found problems"
docker run --rm -v "$HOST_DIR:/repo:ro" -w /repo --entrypoint shellcheck "$ACTIONLINT_IMAGE" \
  scripts/update-gitops.sh scripts/tests/pipeline.sh || fail "shellcheck found problems"
echo "ok    no findings"

step "starting a stand-in for GitHub's runner (bash, git, yq)"
docker build -q -t shoplite/pipeline-test-runner -f scripts/tests/runner.Dockerfile scripts/tests >/dev/null
docker run -d --name "$RUNNER" -v "$HOST_DIR:/app:ro" shoplite/pipeline-test-runner sleep infinity >/dev/null

step "the triggers: a push to main and the \"Run workflow\" button (workflow_dispatch), nothing else"
on_runner <<'EOF' || fail "the workflow's triggers are not exactly a push to main and workflow_dispatch"
wf=/app/.github/workflows/main.yml
triggers=$(yq -o=json -I=0 '.on | keys | sort' "$wf")
[ "$triggers" = '["push","workflow_dispatch"]' ] || { echo "triggers: $triggers"; exit 1; }
push=$(yq -o=json -I=0 '.on.push' "$wf")
[ "$push" = '{"branches":["main"]}' ] || { echo "push trigger: $push"; exit 1; }
echo "ok    on: push to main, workflow_dispatch"
EOF

step "the actions: pinned to the commit of the release in their comment, given only inputs they declare"
on_runner <<'EOF' || fail "an action's pin, inputs or outputs do not match"
wf=/app/.github/workflows/main.yml
mkdir -p /tmp/meta && cd /tmp && git init -q actions && cd actions
steps='[.jobs[].steps[] | select(has("uses"))]'
for i in $(seq 0 $(($(yq "$steps | length" "$wf") - 1))); do
  uses=$(yq "$steps | .[$i] | .uses" "$wf")
  release=$(yq "$steps | .[$i] | .uses | line_comment" "$wf")
  repo=${uses%@*} sha=${uses#*@}
  [[ $sha =~ ^[0-9a-f]{40}$ ]] || { echo "$uses: not pinned to a full commit SHA"; exit 1; }
  git fetch -q --depth=1 "https://github.com/$repo" "refs/tags/$release" || { echo "$repo has no release '$release'"; exit 1; }
  tagged=$(git rev-parse 'FETCH_HEAD^{commit}')
  [ "$tagged" = "$sha" ] || { echo "$repo $release is $tagged, not $sha"; exit 1; }
  git show FETCH_HEAD:action.yml >"/tmp/meta/$sha.yml" 2>/dev/null || git show FETCH_HEAD:action.yaml >"/tmp/meta/$sha.yml"
  given=$(yq "$steps | .[$i] | (.with // {}) | keys | .[]" "$wf")
  for input in $given; do
    [ "$(yq ".inputs | has(\"$input\")" "/tmp/meta/$sha.yml")" = true ] || { echo "$repo $release has no input '$input'"; exit 1; }
  done
  required=$(yq '.inputs // {} | to_entries | .[] | select(.value.required == true and (.value | has("default") | not)) | .key' "/tmp/meta/$sha.yml")
  for input in $required; do
    grep -qx -- "$input" <<<"$given" || { echo "$repo $release needs the input '$input'"; exit 1; }
  done
  inputs=${given//$'\n'/, }
  echo "ok    $repo $release = ${sha:0:12}; inputs: ${inputs:-none}"
done
# The step outputs the workflow reads: an action's declared output, or a line a run step
# writes to $GITHUB_OUTPUT.
for ref in $(grep -o 'steps\.[A-Za-z0-9_-]*\.outputs\.[A-Za-z0-9_-]*' "$wf" | sort -u); do
  id=$(cut -d. -f2 <<<"$ref") name=$(cut -d. -f4 <<<"$ref")
  sel=".jobs[].steps[] | select(.id == \"$id\")"
  uses=$(yq "$sel | .uses // \"\"" "$wf")
  if [ -n "$uses" ]; then
    [ "$(yq ".outputs | has(\"$name\")" "/tmp/meta/${uses#*@}.yml")" = true ] || { echo "${uses%@*} has no output '$name'"; exit 1; }
  else
    yq "$sel | .run" "$wf" | grep -q "$name=.*GITHUB_OUTPUT" || { echo "step '$id' does not write '$name' to \$GITHUB_OUTPUT"; exit 1; }
  fi
  echo "ok    $ref exists"
done
EOF

step "scripts/update-gitops.sh against a copy of shoplite-gitops (a bare repository plays GitHub)"
# The folder's files as Git sees them (tracked and new, not ignored), committed on main.
(cd "$GITOPS_DIR" && git ls-files -z -co --exclude-standard | tar --null -T - -cf -) |
  docker exec -i "$RUNNER" sh -ec 'mkdir /tmp/src && tar -xf - -C /tmp/src'
on_runner <<'EOF' || fail "scripts/update-gitops.sh does not behave as expected"
cd /tmp/src && git init -q -b main && git add -A
git -c user.name=rehearsal -c user.email=rehearsal@example.invalid commit -q -m snapshot
origin=/tmp/origin.git
git clone -q --bare /tmp/src "$origin"
commits() { git -C "$origin" rev-list --count main; }
dev() { git -C "$origin" show main:envs/dev/values.yaml | yq "$1"; }
update=/app/scripts/update-gitops.sh

# 1. The first run, as in the pipeline: one commit by the bot, linked to the run, that
#    changes only dev's values; prod stays as it was; the comments stay.
git clone -q "$origin" /tmp/checkout-1
GITHUB_SERVER_URL=https://github.com GITHUB_REPOSITORY=SaikatGeek/shoplite-app GITHUB_RUN_ID=1001 \
  GITHUB_SHA=0123456789abcdef0123456789abcdef01234567 bash "$update" /tmp/checkout-1 dev "$REGISTRY" 0123456
[ "$(commits)" = 2 ] || { echo "expected one new commit, main has $(commits) commits"; exit 1; }
[ "$(git -C "$origin" log -1 --format='%an <%ae>|%s' main)" = 'github-actions[bot] <41898282+github-actions[bot]@users.noreply.github.com>|dev: images 0123456' ] ||
  { echo "unexpected commit: $(git -C "$origin" log -1 --format='%an <%ae>|%s' main)"; exit 1; }
git -C "$origin" log -1 --format=%b main | grep -q 'https://github.com/SaikatGeek/shoplite-app/actions/runs/1001 from SaikatGeek/shoplite-app@0123456789abcdef' ||
  { echo "the commit does not name the run and the source commit"; exit 1; }
[ "$(git -C "$origin" diff --name-only main~1 main)" = envs/dev/values.yaml ] ||
  { echo "the commit changes more than envs/dev/values.yaml"; exit 1; }
[ "$(dev .image.registry)" = "$REGISTRY" ] && [ "$(dev .image.tag)" = 0123456 ] && [ "$(dev '.image.tag | tag')" = '!!str' ] ||
  { echo "dev's values are wrong: $(dev -o=json -I=0 .image)"; exit 1; }
[ "$(git -C "$origin" show main:envs/dev/values.yaml | grep -c '^#')" = "$(git -C "$origin" show main~1:envs/dev/values.yaml | grep -c '^#')" ] ||
  { echo "the comments of envs/dev/values.yaml were lost"; exit 1; }
echo "ok    first run: one commit by github-actions[bot] (run and source commit in its message), only envs/dev/values.yaml changed, tag \"0123456\" stays a string"

# 2. The same tag again: nothing to commit.
git clone -q "$origin" /tmp/checkout-2
out=$(bash "$update" /tmp/checkout-2 dev "$REGISTRY" 0123456)
grep -q 'nothing to commit' <<<"$out" && [ "$(commits)" = 2 ] || { echo "a rerun with the same tag changed main: $out"; exit 1; }
echo "ok    the same tag again: $out"

# 3. After the pipeline's checkout someone else pushes to main (a chaos flag in prod, and a
#    hand-written dev tag without quotes), and the pipeline's first push is rejected: it
#    tries again from the newest main, and its tag is quoted again.
git clone -q "$origin" /tmp/checkout-3
git clone -q "$origin" /tmp/someone
yq -i '.config.chaos.slowDb = true' /tmp/someone/envs/prod/values.yaml
yq -i '.image.tag = "abc1234" | .image.tag style=""' /tmp/someone/envs/dev/values.yaml
grep -q '^  tag: abc1234$' /tmp/someone/envs/dev/values.yaml || { echo "could not write an unquoted tag"; exit 1; }
git -C /tmp/someone -c user.name=peer -c user.email=peer@example.invalid commit -q -am 'prod: slow database (chaos day)'
git -C /tmp/someone push -q origin HEAD:main
cat >"$origin/hooks/pre-receive" <<'HOOK'
#!/bin/sh
# Test only: the next push is rejected once, like a push that lost a race.
cat >/dev/null
[ -e /tmp/rejected-once ] && exit 0
touch /tmp/rejected-once
echo "rehearsal: push rejected once" >&2
exit 1
HOOK
chmod +x "$origin/hooks/pre-receive"
out=$(bash "$update" /tmp/checkout-3 dev "$REGISTRY" 1e23456 2>&1)
grep -q 'push failed (attempt 1 of 3)' <<<"$out" || { echo "the first push was not retried: $out"; exit 1; }
[ "$(git -C "$origin" log -2 --format=%s main)" = $'dev: images 1e23456\nprod: slow database (chaos day)' ] ||
  { echo "unexpected history: $(git -C "$origin" log -3 --format=%s main)"; exit 1; }
[ "$(git -C "$origin" show main:envs/prod/values.yaml | yq .config.chaos.slowDb)" = true ] || { echo "the other commit was lost"; exit 1; }
[ "$(dev .image.tag)" = 1e23456 ] && [ "$(dev '.image.tag | tag')" = '!!str' ] || { echo "tag 1e23456 is $(dev '.image.tag | tag')"; exit 1; }
rm "$origin/hooks/pre-receive"
echo "ok    rejected push retried from the newest main; the other commit is kept; tag \"1e23456\" stays a string"

# 4. Bad input is refused, and nothing is committed.
git clone -q "$origin" /tmp/checkout-4
for args in "staging $REGISTRY abc1234" "dev https://$REGISTRY abc1234" "dev $REGISTRY/shoplite abc1234" \
  "dev $REGISTRY ../abc1234" "dev $REGISTRY"; do
  # $args unquoted on purpose: one argument per word.
  if bash "$update" /tmp/checkout-4 $args 2>/tmp/error; then echo "accepted bad input: $args"; exit 1; fi
  echo "ok    refused ($args): $(cat /tmp/error)"
done
[ "$(commits)" = 4 ] || { echo "bad input changed main"; exit 1; }
EOF

step "the chart, with the values CI wrote, renders the ECR images with the new tag"
images=$(docker exec "$RUNNER" git -C /tmp/origin.git show main:envs/dev/values.yaml |
  docker run --rm -i -v "$HOST_DIR/helm/shoplite:/chart:ro" --entrypoint sh "$HELM_IMAGE" -c \
    'cat >/tmp/dev.yaml && helm template shoplite /chart --namespace shoplite-dev -f /chart/values-dev.yaml -f /tmp/dev.yaml' |
  sed -n 's/^ *image: *"\{0,1\}\([^"]*\)"\{0,1\}$/\1/p' | sort -u)
for service in web catalog-api order-worker; do
  grep -qx "$REGISTRY/shoplite/$service:1e23456" <<<"$images" ||
    { echo "$images"; fail "the chart does not use $REGISTRY/shoplite/$service:1e23456"; }
done
echo "ok    the dev release's images:"
while read -r image; do echo "        $image"; done <<<"$images"

echo
echo "PASS: the main pipeline's workflow, pinned actions, gitops commit and the chart's images check out"
