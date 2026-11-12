# Remote state in S3 with locking (question 4e). The bucket comes from terraform/bootstrap
# and is given at init time, because its name contains the AWS account id:
#   terraform -chdir=terraform init -backend-config="bucket=<state_bucket>" -backend-config="region=<region>"
# use_lockfile: while Terraform works it keeps a .tflock object next to the state, so two
# runs cannot change the state at the same time (S3's own locking; no DynamoDB table).
terraform {
  backend "s3" {
    key          = "shoplite/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}
