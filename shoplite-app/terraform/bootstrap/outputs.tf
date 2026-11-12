output "state_bucket" {
  description = "Give it to the main configuration: terraform init -backend-config=\"bucket=<this>\""
  value       = aws_s3_bucket.state.bucket
}

output "region" {
  description = "Give it to the main configuration: terraform init -backend-config=\"region=<this>\""
  value       = var.region
}
