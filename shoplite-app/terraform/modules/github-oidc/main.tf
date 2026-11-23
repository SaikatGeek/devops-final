# GitHub Actions in AWS without stored keys (question 7). Every workflow run gets a
# short-lived OpenID Connect token from GitHub; AWS trusts GitHub as an identity provider and
# exchanges that token for temporary credentials of a role. Two roles, each for one kind of
# run of one repository:
#   - the CI role (7a): runs on the main branch; it may only push images to the given ECR
#     repositories;
#   - the plan role (7b): runs for pull requests; it may only read, for terraform plan.
# A pull request never gets the CI role.

# How GitHub's tokens name the repository in their subject (sub). For repositories created
# after 15 July 2026 (shoplite-app: 12 Nov 2026) GitHub uses the immutable form, with the
# owner's and the repository's numeric IDs: repo:OWNER@OWNER-ID/REPO@REPO-ID. A deleted and
# recreated repository of the same name gets a new ID, so it cannot take these roles. The
# repository's own setting shows the prefix its tokens carry:
#   gh api repos/<owner>/<name>/actions/oidc/customization/sub --jq .sub_claim_prefix
# (The older form, repo:OWNER/REPO, never matches these tokens: the first lab run was refused.)
locals {
  owner           = split("/", var.github_repository)[0]
  repository      = split("/", var.github_repository)[1]
  subject_of_repo = "repo:${local.owner}@${var.github_owner_id}/${local.repository}@${var.github_repository_id}"
}

# AWS trusts tokens signed by GitHub Actions. AWS checks GitHub's certificate itself, so no
# thumbprint is pinned here.
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"] # the audience aws-actions/configure-aws-credentials asks for
}

# The CI role. Only a token for a workflow run on main in the given repository can take it
# (exact match: no wildcard, so no other branch, pull request or repository).
resource "aws_iam_role" "ci" {
  name        = "${var.name}-github-ci"
  description = "GitHub Actions of ${var.github_repository}, main branch: push images to ECR"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = "${local.subject_of_repo}:ref:refs/heads/main"
        }
      }
    }]
  })
}

# Everything the role may do: log in to ECR and push to the given repositories (the
# permissions AWS's documentation lists for a push to one repository).
resource "aws_iam_role_policy" "ecr_push" {
  name = "ecr-push"
  role = aws_iam_role.ci.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "EcrLogin"
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken" # cannot be limited to a repository
        Resource = "*"
      },
      {
        Sid    = "PushToTheseRepositories"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage",
          "ecr:CompleteLayerUpload",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart",
        ]
        Resource = var.ecr_repository_arns
      },
    ]
  })
}

# The plan role. Only a token for a pull_request run in the given repository can take it
# (exact match, no wildcard): the pull-request pipeline posts the Terraform plan with it.
resource "aws_iam_role" "plan" {
  name        = "${var.name}-github-plan"
  description = "GitHub Actions of ${var.github_repository}, pull requests: terraform plan, read-only"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = "${local.subject_of_repo}:pull_request"
        }
      }
    }]
  })
}

# Read only: AWS's managed ReadOnlyAccess covers what the plan refreshes (EC2, ELB, ECR, IAM,
# Budgets) and the state in S3. The plan runs with -lock=false, so it writes no lock file.
resource "aws_iam_role_policy_attachment" "plan_read_only" {
  role       = aws_iam_role.plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}
