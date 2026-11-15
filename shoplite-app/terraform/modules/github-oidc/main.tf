# GitHub Actions in AWS without stored keys (question 7a). Every workflow run gets a
# short-lived OpenID Connect token from GitHub; AWS trusts GitHub as an identity provider and
# exchanges that token for temporary credentials of the CI role. Only runs on the main
# branch of one repository can do this, and the role may only push images to the given ECR
# repositories.

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
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_repository}:ref:refs/heads/main"
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
