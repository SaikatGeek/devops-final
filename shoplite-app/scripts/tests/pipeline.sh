#!/usr/bin/env bash
# Rehearses the GitHub Actions workflows (.github/workflows/main.yml and promote.yml) as far
# as they run without GitHub and AWS (the real runs need the split repositories and a lab
# session):
#   1. actionlint checks the workflows and runs shellcheck on their run steps; shellcheck
#      checks the scripts
#   2. main runs on a push to main and from its "Run workflow" button, promote only from its
#      button; main's lint, tests, build and Trivy scan (scripts/ci.sh) always run, before
#      any step that reaches AWS; every action is pinned to the commit of the release its
#      comment names, and gets only inputs that this commit's action.yml declares
#      (actionlint does not know the newest releases); every step output a workflow reads
#      exists; scripts/ci.sh pins every tool image by a digest that exists, and its four
#      stages pass here, while the scan fails on an image with a CRITICAL vulnerability
#      (web's unpatched base image)
#   3. scripts/update-gitops.sh, run the way the main pipeline runs it, against a copy of
#      shoplite-gitops (a bare repository standing in for GitHub, and clones): it writes
#      dev's registry and tag in one commit and pushes it, prod untouched; a rerun with the
#      same tag commits nothing; a rejected push is retried from the newest main, keeping a
#      commit pushed in the meantime; SHAs that look like numbers stay strings; bad input
#      is refused
#   4. promote's own step: prod gets dev's image in one commit, its fault-injection flags
#      kept; with no image in dev yet it stops and commits nothing
#   5. scripts/chaos-pick.sh (question 8 without a peer), against copies of shoplite-gitops:
#      40 runs each turn exactly one fault on in prod, in one line, with GitHub's default
#      message, and never print which; all four faults turn up; with a fault on already it
#      refuses; after a revert it runs again
#   6. the chart, with the values the workflows wrote (layered as the Applications layer
#      them), renders the ECR images with the new tag in dev and in prod
# Needs Docker and internet (images, the actions' repositories on GitHub, Trivy's database). About two
# minutes. Run it from shoplite-app/, with shoplite-gitops next to it (SHOPLITE_GITOPS_DIR
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
# What ECR's login step gives the pipeline (any account and region would do).
REGISTRY=123456789012.dkr.ecr.ap-southeast-1.amazonaws.com
WORKLOG=$(mktemp)

remove_runner() { docker rm -f "$RUNNER" >/dev/null 2>&1 || true; }
trap 'remove_runner; rm -f "$WORKLOG"' EXIT
remove_runner # leftovers of an interrupted earlier run

step() { echo "==> $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }
# on_runner: runs the bash script on stdin in the stand-in for GitHub's runner.
on_runner() { docker exec -i -e REGISTRY="$REGISTRY" "$RUNNER" bash -euo pipefail -s; }

[ -f "$GITOPS_DIR/envs/dev/values.yaml" ] || fail "$GITOPS_DIR/envs/dev/values.yaml not found (set SHOPLITE_GITOPS_DIR)"

step "actionlint on the workflows (with shellcheck on their run steps), shellcheck on the scripts"
docker run --rm -v "$HOST_DIR:/repo:ro" -w /repo "$ACTIONLINT_IMAGE" -no-color .github/workflows/*.yml ||
  fail "actionlint found problems"
docker run --rm -v "$HOST_DIR:/repo:ro" -w /repo --entrypoint shellcheck "$ACTIONLINT_IMAGE" \
  scripts/update-gitops.sh scripts/ci.sh scripts/terraform-plan.sh scripts/chaos-pick.sh scripts/tests/pipeline.sh || fail "shellcheck found problems"
echo "ok    no findings"

step "starting a stand-in for GitHub's runner (bash, git, yq)"
docker build -q -t shoplite/pipeline-test-runner -f scripts/tests/runner.Dockerfile scripts/tests >/dev/null
docker run -d --name "$RUNNER" -v "$HOST_DIR:/app:ro" shoplite/pipeline-test-runner sleep infinity >/dev/null

step "the triggers: main on a push to main and its \"Run workflow\" button, promote on its button only"
on_runner <<'EOF' || fail "a workflow's triggers are not as expected"
cd /app/.github/workflows
check() { # file, yq expression, the JSON it must give
  got=$(yq -o=json -I=0 "$2" "$1")
  [ "$got" = "$3" ] || { echo "$1: $2 is $got, not $3"; exit 1; }
}
check main.yml '.on | keys | sort' '["push","workflow_dispatch"]'
check main.yml '.on.push' '{"branches":["main"]}'
check promote.yml '.on' '{"workflow_dispatch":null}'
check pr.yml '.on' '{"pull_request":{"branches":["main"]}}'
check terraform-plan.yml '.on' '{"pull_request":{"branches":["main"],"paths":["terraform/**"]}}'
echo "ok    main: push to main, workflow_dispatch; promote: workflow_dispatch; pr: pull requests to main; terraform-plan: pull requests to main that change terraform/"
EOF

step "the pull-request workflows: pr runs the checks with no credentials; terraform-plan takes only the read-only plan role"
on_runner <<'EOF' || fail "a pull-request workflow can reach more than it should"
cd /app/.github/workflows
check() { # file, yq expression, the JSON it must give
  got=$(yq -o=json -I=0 "$2" "$1")
  [ "$got" = "$3" ] || { echo "$1: $2 is $got, not $3"; exit 1; }
}
# shellcheck disable=SC2016 # "$TAG" is the steps' own text
check pr.yml '[.jobs[].steps[].run // "" | select(test("scripts/ci.sh"))]' '["bash scripts/ci.sh lint","bash scripts/ci.sh test","bash scripts/ci.sh build \"$TAG\"","bash scripts/ci.sh scan \"$TAG\""]'
check pr.yml '[.jobs[].steps[].uses // "" | select(test("aws-actions"))] | length' '0'
check pr.yml '[.permissions, .jobs[].permissions // {}]' '[{"contents":"read"},{}]'
# shellcheck disable=SC2016 # GitHub's expression, not the shell's
check terraform-plan.yml '[.jobs.plan.steps[].with."role-to-assume" // ""] | map(select(. != ""))' '["${{ vars.AWS_PLAN_ROLE_ARN }}"]'
check terraform-plan.yml '.jobs.plan.permissions' '{"contents":"read","id-token":"write","pull-requests":"write"}'
for file in pr.yml terraform-plan.yml; do
  if grep -n -E 'AWS_ROLE_ARN|GITOPS_DEPLOY_KEY' "$file"; then
    echo "$file must never use the CI role or the gitops deploy key"
    exit 1
  fi
done
grep -q -- '-lock=false' /app/scripts/terraform-plan.sh || { echo "terraform plan must not lock the state"; exit 1; }
echo "ok    pr: the four checks, no AWS, contents: read only; terraform-plan: role AWS_PLAN_ROLE_ARN only, -lock=false; neither names the CI role or the deploy key"
EOF

step "scripts/terraform-plan.sh without AWS credentials: it still writes the comment, and fails"
stub=$(mktemp -d)
printf '#!/bin/sh\necho 123456789012\n' >"$stub/aws"
chmod +x "$stub/aws"
if env -u AWS_ACCESS_KEY_ID -u AWS_SECRET_ACCESS_KEY -u AWS_SESSION_TOKEN PATH="$stub:$PATH" \
  bash scripts/terraform-plan.sh "$stub/plan.md" >"$WORKLOG" 2>&1; then
  rm -rf "$stub"
  fail "scripts/terraform-plan.sh succeeded with no AWS credentials"
fi
if ! grep -q '^\*\*The plan failed\*\* (exit [1-9]' "$stub/plan.md" || ! grep -q '^### Terraform plan of terraform/' "$stub/plan.md"; then
  cat "$stub/plan.md"
  rm -rf "$stub"
  fail "the failed plan's comment is not as expected"
fi
echo "ok    no credentials: exit non-zero, and the comment says the plan failed and shows the output's end"
rm -rf "$stub"

step "main's checks: lint, tests, build and the Trivy scan always run, before anything reaches AWS"
on_runner <<'EOF' || fail "main's checks are missing, conditional, or after a step that reaches AWS"
cd /app/.github/workflows
# One "<if, or always> | <first line of run, or uses>" line per step, in order.
steps=$(yq '.jobs.release.steps[] | (.if // "always") + " | " + ((.run // .uses) | split("\n") | .[0])' main.yml)
# shellcheck disable=SC2016 # "$TAG" is the step's own text
pos() { grep -n -F -- "$1" <<<"$steps" | head -n 1 | cut -d: -f1; }
lint=$(pos 'always | bash scripts/ci.sh lint')
tests=$(pos 'always | bash scripts/ci.sh test')
# shellcheck disable=SC2016
build=$(pos 'always | bash scripts/ci.sh build "$TAG"')
# shellcheck disable=SC2016
scan=$(pos 'always | bash scripts/ci.sh scan "$TAG"')
aws=$(pos 'aws-actions/configure-aws-credentials@')
if [ -z "$lint" ] || [ -z "$tests" ] || [ -z "$build" ] || [ -z "$scan" ] || [ -z "$aws" ] ||
  [ "$lint" -gt "$tests" ] || [ "$tests" -gt "$build" ] || [ "$build" -gt "$scan" ] || [ "$scan" -gt "$aws" ]; then
  echo "$steps"
  exit 1
fi
echo "ok    main: steps $lint lint, $tests tests, $build build, $scan scan, then $aws AWS (OIDC), ECR and gitops"
EOF

step "scripts/ci.sh: every tool image pinned by a digest that exists"
pins=$(sed -n 's/^[A-Z_]*_IMAGE=//p' scripts/ci.sh)
[ "$(grep -c . <<<"$pins")" = 3 ] || fail "scripts/ci.sh should pin three tool images: $pins"
while read -r image; do
  [[ $image =~ ^[a-z0-9./-]+:[A-Za-z0-9._-]+@sha256:[0-9a-f]{64}$ ]] || fail "not pinned by digest: $image"
  docker buildx imagetools inspect "$image" >/dev/null || fail "no such image: $image"
  echo "ok    $image"
done <<<"$pins"

step "scripts/ci.sh, run here as the runner runs it: lint, tests, build and scan"
for stage in lint test "build pipeline-test" "scan pipeline-test"; do
  # shellcheck disable=SC2086 # a stage and its tag
  bash scripts/ci.sh $stage >"$WORKLOG" 2>&1 || { tail -n 30 "$WORKLOG"; fail "scripts/ci.sh $stage failed"; }
  echo "ok    scripts/ci.sh $stage"
done
# The gate's other side: an image with a CRITICAL vulnerability (web's base image before its
# brotli-libs fix) fails the scan, which still scans the other images and names the bad one.
docker image inspect nginxinc/nginx-unprivileged:1.30.6-alpine >/dev/null 2>&1 ||
  docker pull -q nginxinc/nginx-unprivileged:1.30.6-alpine >/dev/null
docker tag nginxinc/nginx-unprivileged:1.30.6-alpine shoplite/web:pipeline-red
docker tag shoplite/catalog-api:pipeline-test shoplite/catalog-api:pipeline-red
docker tag shoplite/order-worker:pipeline-test shoplite/order-worker:pipeline-red
if bash scripts/ci.sh scan pipeline-red >"$WORKLOG" 2>&1; then
  fail "the Trivy scan passed an image with a CRITICAL vulnerability"
fi
grep -q '::error::CRITICAL vulnerabilities in: web$' "$WORKLOG" || { tail -n 20 "$WORKLOG"; fail "the failed scan does not name web"; }
[ "$(grep -c '^==> Trivy: ' "$WORKLOG")" = 3 ] || fail "the failed scan stopped before scanning every image"
echo "ok    scripts/ci.sh scan fails on a CRITICAL vulnerability, after scanning all three images: $(grep -m1 -o 'CVE-[0-9-]*' "$WORKLOG")"
docker rmi shoplite/web:pipeline-red shoplite/catalog-api:pipeline-red shoplite/order-worker:pipeline-red >/dev/null

step "the actions: pinned to the commit of the release in their comment, given only inputs they declare"
on_runner <<'EOF' || fail "an action's pin, inputs or outputs do not match"
mkdir -p /tmp/meta && cd /tmp && git init -q actions && cd actions
steps='[.jobs[].steps[] | select(has("uses"))]'
for wf in /app/.github/workflows/*.yml; do
  for i in $(seq 0 $(($(yq "$steps | length" "$wf") - 1))); do
    uses=$(yq "$steps | .[$i] | .uses" "$wf")
    release=$(yq "$steps | .[$i] | .uses | line_comment" "$wf")
    repo=${uses%@*} sha=${uses#*@}
    [[ $sha =~ ^[0-9a-f]{40}$ ]] || { echo "${wf##*/}: $uses: not pinned to a full commit SHA"; exit 1; }
    git fetch -q --depth=1 "https://github.com/$repo" "refs/tags/$release" || { echo "$repo has no release '$release'"; exit 1; }
    tagged=$(git rev-parse 'FETCH_HEAD^{commit}')
    [ "$tagged" = "$sha" ] || { echo "${wf##*/}: $repo $release is $tagged, not $sha"; exit 1; }
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
    echo "ok    ${wf##*/}: $repo $release = ${sha:0:12}; inputs: ${inputs:-none}"
  done
  # The step outputs the workflow reads: an action's declared output, or a line a run step
  # writes to $GITHUB_OUTPUT.
  for ref in $(grep -o 'steps\.[A-Za-z0-9_-]*\.outputs\.[A-Za-z0-9_-]*' "$wf" | sort -u || true); do
    id=$(cut -d. -f2 <<<"$ref") name=$(cut -d. -f4 <<<"$ref")
    sel=".jobs[].steps[] | select(.id == \"$id\")"
    uses=$(yq "$sel | .uses // \"\"" "$wf")
    if [ -n "$uses" ]; then
      [ "$(yq ".outputs | has(\"$name\")" "/tmp/meta/${uses#*@}.yml")" = true ] || { echo "${uses%@*} has no output '$name'"; exit 1; }
    else
      yq "$sel | .run" "$wf" | grep -q "$name=.*GITHUB_OUTPUT" || { echo "step '$id' does not write '$name' to \$GITHUB_OUTPUT"; exit 1; }
    fi
    echo "ok    ${wf##*/}: $ref exists"
  done
done
EOF

step "scripts/update-gitops.sh and promote's step against a copy of shoplite-gitops (a bare repository plays GitHub)"
# The folder's files as Git sees them (tracked and new, not ignored), committed on main.
(cd "$GITOPS_DIR" && git ls-files -z -co --exclude-standard | tar --null -T - -cf -) |
  docker exec -i "$RUNNER" sh -ec 'mkdir /tmp/src && tar -xf - -C /tmp/src'
on_runner <<'EOF' || fail "scripts/update-gitops.sh or the promote workflow does not behave as expected"
cd /tmp/src && git init -q -b main && git add -A
git -c user.name=rehearsal -c user.email=rehearsal@example.invalid commit -q -m snapshot
origin=/tmp/origin.git
git clone -q --bare /tmp/src "$origin"
commits() { git -C "$origin" rev-list --count main; }
dev() { git -C "$origin" show main:envs/dev/values.yaml | yq "$@"; }
prod() { git -C "$origin" show main:envs/prod/values.yaml | yq "$@"; }
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
[ "$(prod .config.chaos.slowDb)" = true ] || { echo "the other commit was lost"; exit 1; }
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

# 5. The promote workflow's own step, run as on GitHub (shoplite-gitops checked out inside
#    shoplite-app): one commit by the bot gives prod dev's image (1e23456) and changes
#    nothing else; prod's fault-injection flag from case 3 stays on.
promote_step=$(yq '.jobs.promote.steps[] | select(.id == "promote") | .run' /app/.github/workflows/promote.yml)
[ -n "$promote_step" ] || { echo "promote.yml has no step with id promote"; exit 1; }
workspace() { # a GitHub workspace: shoplite-app's scripts, and a checkout of the given origin
  mkdir -p "$1/scripts" && cp "$update" "$1/scripts/"
  git clone -q "$2" "$1/shoplite-gitops"
}
workspace /tmp/promote-1 "$origin"
out=$(cd /tmp/promote-1 && GITHUB_SERVER_URL=https://github.com GITHUB_REPOSITORY=SaikatGeek/shoplite-app \
  GITHUB_RUN_ID=1002 GITHUB_SHA=fedcba9876543210fedcba9876543210fedcba98 bash -e -c "$promote_step" 2>&1) ||
  { echo "promote failed: $out"; exit 1; }
[ "$(commits)" = 5 ] || { echo "expected one new commit, main has $(commits) commits"; exit 1; }
[ "$(git -C "$origin" log -1 --format='%an|%s' main)" = 'github-actions[bot]|prod: images 1e23456' ] ||
  { echo "unexpected commit: $(git -C "$origin" log -1 --format='%an|%s' main)"; exit 1; }
git -C "$origin" log -1 --format=%b main | grep -qx 'Promoted from dev by https://github.com/SaikatGeek/shoplite-app/actions/runs/1002.' ||
  { echo "the commit does not name the promote run: $(git -C "$origin" log -1 --format=%b main)"; exit 1; }
[ "$(git -C "$origin" diff --name-only main~1 main)" = envs/prod/values.yaml ] ||
  { echo "the commit changes more than envs/prod/values.yaml"; exit 1; }
[ "$(prod .image.registry)" = "$REGISTRY" ] && [ "$(prod .image.tag)" = 1e23456 ] && [ "$(prod '.image.tag | tag')" = '!!str' ] ||
  { echo "prod's image is wrong: $(prod -o=json -I=0 .image)"; exit 1; }
[ "$(prod .config.chaos.slowDb)" = true ] || { echo "promote lost prod's fault-injection flag"; exit 1; }
grep -q '^::notice::.*Sync shoplite-prod in ArgoCD' <<<"$out" || { echo "no notice to sync prod: $out"; exit 1; }
echo "ok    promote: one commit by github-actions[bot] gives prod dev's image (\"1e23456\", a string); prod's chaos flag kept"

# 6. promote before the main pipeline has given dev an image: it stops and commits nothing.
git clone -q --bare /tmp/src /tmp/origin-new.git
workspace /tmp/promote-2 /tmp/origin-new.git
if out=$(cd /tmp/promote-2 && bash -e -c "$promote_step" 2>&1); then echo "promote went on with no image in dev: $out"; exit 1; fi
grep -q '^::error::dev has no image yet' <<<"$out" || { echo "promote failed in another way: $out"; exit 1; }
[ "$(git -C /tmp/origin-new.git rev-list --count main)" = 1 ] || { echo "promote committed with no image in dev"; exit 1; }
echo "ok    promote with no image in dev yet: $out"
EOF

step "scripts/chaos-pick.sh (question 8 without a peer) against copies of shoplite-gitops"
on_runner <<'EOF' || fail "scripts/chaos-pick.sh does not behave as expected"
export GIT_AUTHOR_NAME=student GIT_AUTHOR_EMAIL=student@example.invalid \
  GIT_COMMITTER_NAME=student GIT_COMMITTER_EMAIL=student@example.invalid
pick=/app/scripts/chaos-pick.sh
chaos() { git -C "$1" show main:envs/prod/values.yaml | yq -o=json -I=0 '.config.chaos'; }
names_a_fault() { grep -qiE 'latency|error|memory|leak|slow|db' <<<"$1"; }

# 1. Forty runs, each on a fresh copy: one commit with GitHub's default message, one line of
#    prod's values, exactly one fault on, and an output that never names it. All four faults
#    must turn up (the chance that one never does is about 4 in 100000).
seen=""
for i in $(seq 1 40); do
  origin=/tmp/chaos-$i.git
  git clone -q --bare /tmp/src "$origin"
  out=$(cd /tmp && CHAOS_GITOPS_URL="$origin" bash "$pick" "/tmp/chaos-clone-$i" 2>&1) || { echo "run $i failed: $out"; exit 1; }
  [ "$(git -C "$origin" rev-list --count main)" = 2 ] || { echo "run $i: expected one new commit"; exit 1; }
  [ "$(git -C "$origin" log -1 --format='%an|%s' main)" = 'student|Update values.yaml' ] ||
    { echo "run $i: unexpected commit: $(git -C "$origin" log -1 --format='%an|%s' main)"; exit 1; }
  [ "$(git -C "$origin" diff --numstat main~1 main)" = "$(printf '1\t1\tenvs/prod/values.yaml')" ] ||
    { echo "run $i: the commit changes more than one line of prod's values"; exit 1; }
  case "$(chaos "$origin")" in
    '{"latencyMs":1500,"errorRate":0,"memoryLeak":false,"slowDb":false}') seen="$seen latency" ;;
    '{"latencyMs":0,"errorRate":0.2,"memoryLeak":false,"slowDb":false}') seen="$seen error" ;;
    '{"latencyMs":0,"errorRate":0,"memoryLeak":true,"slowDb":false}') seen="$seen memory" ;;
    '{"latencyMs":0,"errorRate":0,"memoryLeak":false,"slowDb":true}') seen="$seen slowdb" ;;
    *) echo "run $i: not exactly one fault on: $(chaos "$origin")"; exit 1 ;;
  esac
  if names_a_fault "$out"; then echo "run $i: the output names the fault: $out"; exit 1; fi
done
for fault in latency error memory slowdb; do
  grep -qw "$fault" <<<"$seen" || { echo "40 runs never chose $fault"; exit 1; }
done
echo "ok    40 runs: one fault on, one line, 'Update values.yaml', never named; all four were chosen"

# 2. With a fault on already, it refuses, commits nothing, and names nothing.
if out=$(cd /tmp && CHAOS_GITOPS_URL=/tmp/chaos-1.git bash "$pick" /tmp/chaos-clone-1 2>&1); then
  echo "a second fault was turned on: $out"; exit 1
fi
grep -q 'not all off' <<<"$out" || { echo "refused for another reason: $out"; exit 1; }
if names_a_fault "$out"; then echo "the refusal names the fault: $out"; exit 1; fi
[ "$(git -C /tmp/chaos-1.git rev-list --count main)" = 2 ] || { echo "the refusal committed"; exit 1; }
echo "ok    a fault on already: refused, nothing committed: $out"

# 3. After section 6's revert (from the same clone), it runs again.
git -C /tmp/chaos-clone-1 revert --no-edit HEAD >/dev/null && git -C /tmp/chaos-clone-1 push -q origin HEAD:main
[ "$(chaos /tmp/chaos-1.git)" = '{"latencyMs":0,"errorRate":0,"memoryLeak":false,"slowDb":false}' ] ||
  { echo "the revert did not turn the fault off"; exit 1; }
out=$(cd /tmp && CHAOS_GITOPS_URL=/tmp/chaos-1.git bash "$pick" /tmp/chaos-clone-1 2>&1) || { echo "after the revert it refused: $out"; exit 1; }
[ "$(git -C /tmp/chaos-1.git rev-list --count main)" = 4 ] || { echo "after the revert: expected one new commit"; exit 1; }
echo "ok    after the revert, from the same clone: one new fault"
EOF

step "the chart, with the values the workflows wrote, renders the ECR images with the new tag"
for env in dev prod; do
  if [ "$env" = prod ]; then namespace=shoplite; else namespace=shoplite-dev; fi
  images=$(docker exec "$RUNNER" git -C /tmp/origin.git show "main:envs/$env/values.yaml" |
    docker run --rm -i -v "$HOST_DIR/helm/shoplite:/chart:ro" --entrypoint sh "$HELM_IMAGE" -c \
      "cat >/tmp/env.yaml && helm template shoplite /chart --namespace $namespace -f /chart/values-$env.yaml -f /tmp/env.yaml" |
    sed -n 's/^ *image: *"\{0,1\}\([^"]*\)"\{0,1\}$/\1/p' | sort -u)
  for service in web catalog-api order-worker; do
    grep -qx "$REGISTRY/shoplite/$service:1e23456" <<<"$images" ||
      { echo "$images"; fail "$env: the chart does not use $REGISTRY/shoplite/$service:1e23456"; }
  done
  echo "ok    the $env release's images (namespace $namespace):"
  while read -r image; do echo "        $image"; done <<<"$images"
done

echo
echo "PASS: the workflows, their pinned actions, the gitops commits of main and promote, and the chart's images check out"
