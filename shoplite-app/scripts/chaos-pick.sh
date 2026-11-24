#!/usr/bin/env bash
# Question 8 without a peer. The question lets "a peer or the instructor" turn one fault on;
# the instructor asked the student to run the exercise alone (24 Nov). So that the
# investigation still starts blind, this script plays the peer's part:
#   - it turns ONE of question 1.5's four fault-injection settings on in prod's values
#     (shoplite-gitops envs/prod/values.yaml), chosen at random;
#   - it commits that with GitHub's innocuous default message and pushes it to main;
#   - it never prints which setting it chose: only the commit's short hash, for the timeline.
# Do not read the change (no git show or diff, no commit page, no APP DIFF in ArgoCD) until
# the RCA is written: docs/evidence/q8/commands.md, sections 4 to 9.
#
# Run it on a computer that can push to shoplite-gitops (your own PC, in Git Bash):
#   bash scripts/chaos-pick.sh [clone folder, default q8-gitops]
# The folder is cloned when missing, or brought up to date; section 6's revert uses it too.
# It stops, changing nothing, unless all four settings are off.
set -euo pipefail

repo_url=${CHAOS_GITOPS_URL:-https://github.com/SaikatGeek/shoplite-gitops.git}
dir=${1:-q8-gitops}
file=envs/prod/values.yaml
message='Update values.yaml'

# The four faults, the same values a peer would choose from: "off|on", as the lines appear
# under config.chaos in prod's values (four spaces deep).
faults=(
  'latencyMs: 0|latencyMs: 1500'
  'errorRate: 0|errorRate: 0.2'
  'memoryLeak: false|memoryLeak: true'
  'slowDb: false|slowDb: true'
)

stop() { echo "chaos-pick: $*" >&2; exit 1; }

if [ -d "$dir/.git" ]; then
  git -C "$dir" pull -q --ff-only || stop "cannot bring $dir up to date"
else
  git clone -q "$repo_url" "$dir" || stop "cannot clone $repo_url"
fi
cd "$dir"
[ -f "$file" ] || stop "$file not found in $dir"
[ -z "$(git status --porcelain)" ] || stop "$dir has local changes; nothing changed"

# Every fault must be off, each exactly once; otherwise one is on already, or the file has
# changed shape. The check names no setting in its message.
for fault in "${faults[@]}"; do
  [ "$(grep -c "^    ${fault%%|*}\$" "$file")" = 1 ] ||
    stop "prod's faults are not all off; nothing changed (revert the earlier fault first)"
done

pick=$((RANDOM % ${#faults[@]}))
off=${faults[$pick]%%|*}
on=${faults[$pick]#*|}
sed -i "s/^    ${off}\$/    ${on}/" "$file"

# Exactly one line of that one file changed.
[ "$(git diff --name-only)" = "$file" ] && [ "$(git diff --numstat | cut -f1,2)" = "$(printf '1\t1')" ] ||
  { git checkout -q -- "$file"; stop "the change was not one line of $file; nothing committed"; }

git commit -q -m "$message" -- "$file"
git push -q origin HEAD:main || stop "the push failed; the commit is only local (git reset --hard origin/main to drop it)"

echo "One fault is on in prod: commit $(git rev-parse --short HEAD) is on shoplite-gitops main."
echo "Which one is not shown. Sync shoplite-prod in ArgoCD without APP DIFF, then find it in Grafana."
