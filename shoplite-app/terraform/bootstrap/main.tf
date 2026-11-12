# The S3 bucket that keeps the Terraform state of the main configuration in ../
# (question 4e: remote state with locking). Run it once per AWS account, before ../:
#   terraform -chdir=terraform/bootstrap init
#   terraform -chdir=terraform/bootstrap apply
# Its own small state stays local (git-ignored): a bucket cannot hold the state of its
# own creation.

terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.73"
    }
  }
}

provider "aws" {
  region = var.region
  # Cost guard: every resource that supports tags gets project=shoplite.
  default_tags {
    tags = { project = "shoplite" }
  }
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "state" {
  # Bucket names are global; the account id and the region make this one unique.
  bucket = "shoplite-tfstate-${data.aws_caller_identity.current.account_id}-${var.region}"
  # `terraform destroy` after grading removes the bucket even with state files inside.
  force_destroy = true
}

# Every change of the state keeps the previous version, so a damaged state can be
# restored (HashiCorp's advice for the S3 backend). New buckets are already encrypted
# and closed to the public by default, so nothing else is needed.
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}
