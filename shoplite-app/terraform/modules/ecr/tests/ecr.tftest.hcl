# Unit tests without AWS: the aws provider is mocked; `command = apply` (offline) fills in
# the repository URLs so the outputs can be checked.

mock_provider "aws" {
  mock_resource "aws_ecr_repository" {
    defaults = {
      repository_url = "123456789012.dkr.ecr.ap-southeast-1.amazonaws.com/shoplite/example"
    }
  }
}

variables {
  name = "shoplite"
}

run "one_repository_per_application_image" {
  command = apply

  assert {
    condition     = toset([for r in aws_ecr_repository.app : r.name]) == toset(["shoplite/web", "shoplite/catalog-api", "shoplite/order-worker"])
    error_message = "There must be exactly the three repositories shoplite/web, shoplite/catalog-api and shoplite/order-worker."
  }

  assert {
    condition     = alltrue([for r in aws_ecr_repository.app : r.force_delete])
    error_message = "force_delete must be on, so terraform destroy also removes repositories that hold images."
  }
}

run "outputs_list_every_repository_by_short_name" {
  command = apply

  assert {
    condition     = keys(output.repository_urls) == ["catalog-api", "order-worker", "web"]
    error_message = "repository_urls must have one entry per image, keyed by its short name."
  }

  assert {
    condition     = output.repository_urls["web"] == aws_ecr_repository.app["web"].repository_url && output.repository_arns["web"] == aws_ecr_repository.app["web"].arn
    error_message = "Each entry must point at its own repository."
  }

  assert {
    condition     = output.registry == "123456789012.dkr.ecr.ap-southeast-1.amazonaws.com"
    error_message = "registry must be the host part of the repository URL."
  }
}

run "another_set_of_repositories" {
  command = plan

  variables {
    repositories = ["api"]
  }

  assert {
    condition     = keys(aws_ecr_repository.app) == ["api"]
    error_message = "The module must create whatever repositories it is given."
  }
}

run "rejects_bad_or_repeated_names" {
  command = plan

  variables {
    repositories = ["Web", "web", "web"]
  }

  expect_failures = [var.repositories]
}
