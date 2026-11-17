#!/usr/bin/env bash
# Publishes the two repositories the question asks for, from this repository's folders of
# the same names: shoplite-app -> SaikatGeek/shoplite-app, shoplite-gitops ->
# SaikatGeek/shoplite-gitops (question 5's procedure, section 0.1).
#   1. git subtree split: each folder's history as a branch of its own, split/<folder>
#   2. the commit messages lose the coding assistant's Co-Authored-By trailer, and the root's
#      notes file (named after the assistant) is called "the project notes": the user's rule
#      (17 Nov) is that nothing in these two repositories carries the assistant's name.
#      Authors, committers and dates stay, so every run gives the same commits, and a later
#      push is a fast-forward.
#   3. with "push": push both branches to GitHub's main, as fast-forwards only (the very first
#      publication of shoplite-app replaced its placeholder with a force push, once)
# Run it from devops-final's root, with no uncommitted changes:
#   bash publish-repos.sh          split and clean; prints each branch's commit
#   bash publish-repos.sh push     the same, then push
set -euo pipefail
cd "$(dirname "$0")"

FOLDERS="shoplite-app shoplite-gitops"
OWNER=SaikatGeek

[ -z "$(git status --porcelain)" ] || { echo "commit or stash your changes first" >&2; exit 1; }

# The message filter: drop the trailer, rename the notes file, drop trailing empty lines.
filter=$(mktemp)
trap 'rm -f "$filter"' EXIT
cat >"$filter" <<'EOF'
sed -e '/^Co-Authored-By: Claude/d' -e "s/CLAUDE\.md's/the project notes'/g" -e 's/CLAUDE\.md/the project notes/g' |
  awk '{ line[++n] = $0 } END { while (n > 0 && line[n] == "") n--; for (i = 1; i <= n; i++) print line[i] }'
EOF

for folder in $FOLDERS; do
  echo "==> $folder"
  commit=$(git subtree split --prefix="$folder" 2>/dev/null)
  git branch -f "split/$folder" "$commit"
  FILTER_BRANCH_SQUELCH_WARNING=1 git filter-branch -f --msg-filter "sh '$filter'" -- "split/$folder" >/dev/null 2>&1
  git update-ref -d "refs/original/refs/heads/split/$folder"
  if git log --format='%an%n%cn%n%B' "split/$folder" | grep -qi 'claude\|anthropic'; then
    echo "split/$folder still names the assistant" >&2
    exit 1
  fi
  echo "split/$folder: $(git rev-parse --short "split/$folder"), $(git rev-list --count "split/$folder") commits"
  if [ "${1:-}" = push ]; then
    git push "https://github.com/$OWNER/$folder.git" "split/$folder:main"
  fi
done
