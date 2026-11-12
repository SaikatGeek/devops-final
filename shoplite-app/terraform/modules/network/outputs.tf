output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "Address range of the VPC (for security-group rules that allow traffic from inside it)."
  value       = aws_vpc.this.cidr_block
}

output "azs" {
  description = "The Availability Zones used, in subnet order."
  value       = local.azs
}

output "public_subnet_ids" {
  description = "Public subnets, one per AZ: for the ALB."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnets, one per AZ: for the Kubernetes nodes."
  value       = aws_subnet.private[*].id
}
