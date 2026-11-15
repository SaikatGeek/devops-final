# Unit tests without AWS: the aws provider is mocked; `command = apply` (offline) fills in the
# identity provider's and the role's ARNs so the policies and outputs can be checked.

mock_provider "aws" {
  mock_resource "aws_iam_openid_connect_provider" {
    defaults = {
      arn = "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/shoplite-github-ci"
    }
  }
}

variables {
  name              = "shoplite"
  github_repository = "SaikatGeek/shoplite-app"
  ecr_repository_arns = [
    "arn:aws:ecr:ap-southeast-1:123456789012:repository/shoplite/catalog-api",
    "arn:aws:ecr:ap-southeast-1:123456789012:repository/shoplite/order-worker",
    "arn:aws:ecr:ap-southeast-1:123456789012:repository/shoplite/web",
  ]
}

run "aws_trusts_the_tokens_of_github_actions" {
  command = apply

  assert {
    condition     = aws_iam_openid_connect_provider.github.url == "https://token.actions.githubusercontent.com"
    error_message = "The identity provider must be the token issuer of GitHub Actions."
  }

  assert {
    condition     = toset(aws_iam_openid_connect_provider.github.client_id_list) == toset(["sts.amazonaws.com"])
    error_message = "Only tokens meant for AWS STS (audience sts.amazonaws.com) may be accepted."
  }
}

run "only_main_of_the_repository_can_take_the_role" {
  command = apply

  assert {
    condition     = aws_iam_role.ci.name == "shoplite-github-ci"
    error_message = "The CI role must be called <name>-github-ci."
  }

  assert {
    condition     = length(jsondecode(aws_iam_role.ci.assume_role_policy).Statement) == 1
    error_message = "The trust policy must have exactly one statement."
  }

  assert {
    condition = alltrue([
      jsondecode(aws_iam_role.ci.assume_role_policy).Statement[0].Effect == "Allow",
      jsondecode(aws_iam_role.ci.assume_role_policy).Statement[0].Action == "sts:AssumeRoleWithWebIdentity",
      jsondecode(aws_iam_role.ci.assume_role_policy).Statement[0].Principal == { Federated = aws_iam_openid_connect_provider.github.arn },
    ])
    error_message = "Only a web identity from the GitHub identity provider may take the role."
  }

  assert {
    condition = jsondecode(aws_iam_role.ci.assume_role_policy).Statement[0].Condition == {
      StringEquals = {
        "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        "token.actions.githubusercontent.com:sub" = "repo:SaikatGeek/shoplite-app:ref:refs/heads/main"
      }
    }
    error_message = "The token must match exactly (no wildcard): audience sts.amazonaws.com, a run on main in SaikatGeek/shoplite-app."
  }
}

run "the_role_may_only_log_in_and_push_to_the_given_repositories" {
  command = apply

  assert {
    condition     = aws_iam_role_policy.ecr_push.role == aws_iam_role.ci.name
    error_message = "The push policy must belong to the CI role."
  }

  assert {
    condition     = length(jsondecode(aws_iam_role_policy.ecr_push.policy).Statement) == 2
    error_message = "The policy must have exactly two statements: the ECR login and the push."
  }

  assert {
    condition = alltrue([
      jsondecode(aws_iam_role_policy.ecr_push.policy).Statement[0].Effect == "Allow",
      jsondecode(aws_iam_role_policy.ecr_push.policy).Statement[0].Action == "ecr:GetAuthorizationToken",
      jsondecode(aws_iam_role_policy.ecr_push.policy).Statement[0].Resource == "*",
    ])
    error_message = "The only account-wide permission must be the ECR login (GetAuthorizationToken)."
  }

  assert {
    condition = alltrue([
      jsondecode(aws_iam_role_policy.ecr_push.policy).Statement[1].Effect == "Allow",
      toset(jsondecode(aws_iam_role_policy.ecr_push.policy).Statement[1].Action) == toset([
        "ecr:BatchCheckLayerAvailability",
        "ecr:BatchGetImage",
        "ecr:CompleteLayerUpload",
        "ecr:InitiateLayerUpload",
        "ecr:PutImage",
        "ecr:UploadLayerPart",
      ]),
    ])
    error_message = "The second statement must allow exactly the six actions of an image push, nothing else (no delete, no wildcard)."
  }

  assert {
    condition     = tolist(jsondecode(aws_iam_role_policy.ecr_push.policy).Statement[1].Resource) == var.ecr_repository_arns
    error_message = "The push must be limited to exactly the given repositories."
  }
}

run "outputs_name_the_role_and_the_identity_provider" {
  command = apply

  assert {
    condition     = output.role_arn == "arn:aws:iam::123456789012:role/shoplite-github-ci"
    error_message = "role_arn must be the CI role's ARN."
  }

  assert {
    condition     = output.oidc_provider_arn == aws_iam_openid_connect_provider.github.arn
    error_message = "oidc_provider_arn must be the GitHub identity provider's ARN."
  }
}

run "rejects_a_repository_url_instead_of_owner_and_name" {
  command = plan

  variables {
    github_repository = "https://github.com/SaikatGeek/shoplite-app"
  }

  expect_failures = [var.github_repository]
}

run "rejects_a_wildcard_repository" {
  command = plan

  variables {
    github_repository = "SaikatGeek/*"
  }

  expect_failures = [var.github_repository]
}

run "rejects_a_wildcard_repository_arn" {
  command = plan

  variables {
    ecr_repository_arns = ["arn:aws:ecr:ap-southeast-1:123456789012:repository/*"]
  }

  expect_failures = [var.ecr_repository_arns]
}

run "rejects_an_empty_list_of_repositories" {
  command = plan

  variables {
    ecr_repository_arns = []
  }

  expect_failures = [var.ecr_repository_arns]
}
