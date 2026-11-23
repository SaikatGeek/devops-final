#!/usr/bin/env bash
# The Terraform plan of the root configuration (terraform/) for a pull request (question 7b),
# written as the markdown of a pull-request comment to the file given (default plan.md).
# .github/workflows/terraform-plan.yml runs it with the read-only plan role's credentials in
# the environment, then posts the file. It also needs Docker, the AWS CLI, and the same
# TF_VAR_ssh_public_key, TF_VAR_budget_alert_email and TF_VAR_admin_cidr as terraform apply. The state is in the
# bootstrap's bucket shoplite-tfstate-<account>-<region>; the plan runs with -lock=false, so it
# writes nothing there. It exits non-zero when init or plan fails, after writing the comment.
set -euo pipefail
cd "$(dirname "$0")/.."

export MSYS_NO_PATHCONV=1 # Git Bash on Windows: leave container paths alone
HOST_DIR=$(pwd -W 2>/dev/null || pwd)
TERRAFORM_IMAGE=hashicorp/terraform:1.17.2@sha256:6e9c1e647c31a960dc9b59e13272f9111d90010c10b717f77ffb324767660475
OUT=${1:-plan.md}
REGION=${AWS_REGION:-ap-southeast-1}
# A comment holds at most 65536 characters; the end of a long plan matters most.
KEEP=60000
LOG=$(mktemp)
trap 'rm -f "$LOG"' EXIT

tf() {
  docker run --rm -v "$HOST_DIR/terraform:/tf" -w /tf -e TF_IN_AUTOMATION=1 \
    -e AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY -e AWS_SESSION_TOKEN -e AWS_REGION="$REGION" \
    -e TF_VAR_ssh_public_key -e TF_VAR_budget_alert_email -e TF_VAR_admin_cidr "$TERRAFORM_IMAGE" "$@"
}
# write <headline>: the comment, with the log in a folded block.
write() {
  {
    echo "### Terraform plan of terraform/"
    echo
    echo "Commit \`${GITHUB_SHA:-local}\`, against the lab's AWS account in $REGION: the read-only plan role, no state lock."
    echo
    echo "$1"
    echo
    echo "<details><summary>The whole output</summary>"
    echo
    echo '```text'
    tail -c "$KEEP" "$LOG"
    echo '```'
    echo
    echo "</details>"
  } >"$OUT"
}

status=0
account=$(aws sts get-caller-identity --query Account --output text 2>>"$LOG") || status=$?
if [ "$status" = 0 ]; then
  tf init -input=false -no-color -backend-config="bucket=shoplite-tfstate-$account-$REGION" \
    -backend-config="region=$REGION" >>"$LOG" 2>&1 || status=$?
fi
if [ "$status" = 0 ]; then
  tf plan -input=false -no-color -lock=false >>"$LOG" 2>&1 || status=$?
fi

if [ "$status" = 0 ]; then
  summary=$(grep -E '^(Plan: |No changes\.)' "$LOG" | tail -n 1)
  write "**${summary:-The plan finished.}**"
else
  write "**The plan failed** (exit $status): see the end of the output."
fi
exit "$status"
