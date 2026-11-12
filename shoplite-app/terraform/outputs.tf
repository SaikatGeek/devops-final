output "vpc_id" {
  description = "ID of the ShopLite VPC."
  value       = module.network.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnets (ALB, NAT Gateway), one per AZ."
  value       = module.network.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnets (Kubernetes nodes), one per AZ."
  value       = module.network.private_subnet_ids
}

output "control_plane_instance_id" {
  description = "k3s server; open a shell with: aws ssm start-session --target <id>"
  value       = module.compute.control_plane_instance_id
}

output "worker_instance_ids" {
  description = "k3s agents (SSM targets)."
  value       = module.compute.worker_instance_ids
}
