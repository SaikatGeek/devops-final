# ShopLite on AWS (question 4). The modules are added step by step:
# network (VPC), compute (Kubernetes nodes), alb (load balancer), ecr (image repositories).
#
# Once per account run terraform/bootstrap (the state bucket), then:
#   terraform -chdir=terraform init -backend-config="bucket=<state_bucket>" -backend-config="region=<region>"
#   TF_VAR_budget_alert_email=<your e-mail> terraform -chdir=terraform apply
# After grading: terraform -chdir=terraform destroy (cost guard).

terraform {
  required_version = ">= 1.10" # the S3 backend's use_lockfile needs 1.10 or newer
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

# Question 4a: VPC over two AZs, two public and two private subnets, IGW, NAT Gateway.
module "network" {
  source = "./modules/network"
  name   = "shoplite"
}

# Questions 4b and 4c: least-privilege security groups, SSM access, one control-plane
# and two workers in the private subnets.
module "compute" {
  source             = "./modules/compute"
  name               = "shoplite"
  vpc_id             = module.network.vpc_id
  private_subnet_ids = module.network.private_subnet_ids
}

# Cost guard: an e-mail as soon as this month's actual cost passes USD 20.
resource "aws_budgets_budget" "monthly" {
  name         = "shoplite-monthly"
  budget_type  = "COST"
  limit_amount = "20"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100 # percent of the USD 20 limit
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_alert_email]
  }
}
