# Unit tests without AWS: the aws provider is mocked, so `terraform test` plans offline.
# Run after `terraform init -backend=false` (tests never touch the S3 backend).

mock_provider "aws" {}

variables {
  budget_alert_email = "alerts@example.com"
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
