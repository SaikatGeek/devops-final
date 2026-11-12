# Unit tests without AWS: the aws provider is mocked, so `terraform test` plans offline.
# Run after `terraform init -backend=false` (tests never touch the S3 backend).

mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = {
      names = ["ap-southeast-1a", "ap-southeast-1b", "ap-southeast-1c"]
    }
  }

  # The provider validates ARN arguments (listener -> load balancer, target group), so the
  # mocked load balancer and target groups need well-formed ARNs.
  mock_resource "aws_lb" {
    defaults = {
      arn      = "arn:aws:elasticloadbalancing:ap-southeast-1:123456789012:loadbalancer/app/shoplite/1111111111111111"
      dns_name = "shoplite-1234567890.ap-southeast-1.elb.amazonaws.com"
    }
  }

  mock_resource "aws_lb_target_group" {
    defaults = {
      arn = "arn:aws:elasticloadbalancing:ap-southeast-1:123456789012:targetgroup/shoplite/2222222222222222"
    }
  }
}

variables {
  budget_alert_email = "alerts@example.com"
}

run "network_module_gives_two_public_and_two_private_subnets" {
  command = apply

  assert {
    condition     = length(output.public_subnet_ids) == 2 && length(output.private_subnet_ids) == 2
    error_message = "The root configuration must expose two public and two private subnets."
  }
}

run "compute_module_puts_the_nodes_in_the_private_subnets" {
  command = apply

  assert {
    condition     = length(output.worker_instance_ids) == 2 && output.control_plane_instance_id != ""
    error_message = "The root configuration must create one control plane and two workers."
  }

  assert {
    condition     = module.compute.control_plane_private_ip != null
    error_message = "The control plane must have a private IP for the agents to join."
  }
}

run "alb_gives_a_prod_and_a_dev_url" {
  command = apply

  assert {
    condition     = keys(output.app_urls) == ["dev", "prod"] && endswith(output.app_urls["dev"], ":8080")
    error_message = "The root configuration must expose the prod URL and the dev URL on port 8080."
  }
}

run "budget_alarm_at_20_usd" {
  command = plan

  assert {
    condition     = aws_budgets_budget.monthly.limit_amount == "20" && aws_budgets_budget.monthly.limit_unit == "USD"
    error_message = "The budget must be USD 20."
  }

  assert {
    condition     = aws_budgets_budget.monthly.time_unit == "MONTHLY" && aws_budgets_budget.monthly.budget_type == "COST"
    error_message = "The budget must count the monthly cost."
  }

  assert {
    condition = alltrue([
      one(aws_budgets_budget.monthly.notification).threshold == 100,
      one(aws_budgets_budget.monthly.notification).threshold_type == "PERCENTAGE",
      one(aws_budgets_budget.monthly.notification).notification_type == "ACTUAL",
      one(aws_budgets_budget.monthly.notification).comparison_operator == "GREATER_THAN",
    ])
    error_message = "The alarm must fire when the actual cost passes 100% of the limit, i.e. USD 20."
  }

  assert {
    condition     = one(aws_budgets_budget.monthly.notification).subscriber_email_addresses == toset(["alerts@example.com"])
    error_message = "The alarm must go to budget_alert_email."
  }
}

run "rejects_a_value_that_is_not_an_email" {
  command = plan

  variables {
    budget_alert_email = "not-an-email"
  }

  expect_failures = [var.budget_alert_email]
}
