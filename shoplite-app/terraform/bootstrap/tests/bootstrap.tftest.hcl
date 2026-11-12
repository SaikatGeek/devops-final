# Unit tests without AWS: the aws provider is mocked, so `terraform test` plans offline.

mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }
}

run "bucket_name_contains_account_and_region" {
  command = plan

  assert {
    condition     = aws_s3_bucket.state.bucket == "shoplite-tfstate-123456789012-ap-southeast-1"
    error_message = "The state bucket must be named shoplite-tfstate-<account id>-<region>."
  }
}

run "bucket_keeps_old_states_and_can_be_destroyed" {
  command = plan

  assert {
    condition     = aws_s3_bucket_versioning.state.versioning_configuration[0].status == "Enabled"
    error_message = "Versioning must be on, so an older state can be restored."
  }

  assert {
    condition     = aws_s3_bucket.state.force_destroy
    error_message = "force_destroy must be on, so terraform destroy also removes a non-empty bucket."
  }
}

run "region_can_be_changed" {
  command = plan

  variables {
    region = "us-east-1"
  }

  assert {
    condition     = aws_s3_bucket.state.bucket == "shoplite-tfstate-123456789012-us-east-1"
    error_message = "The bucket name must follow the region variable."
  }
}
