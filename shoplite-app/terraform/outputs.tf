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
