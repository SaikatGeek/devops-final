# Same state bucket as the main configuration (from ../bootstrap), its own key and lock.
#   terraform -chdir=terraform/q3-server init -backend-config="bucket=<state_bucket>" -backend-config="region=<region>"
terraform {
  backend "s3" {
    key          = "q3-server/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}
