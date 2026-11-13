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

output "ansible_inventory" {
  description = "Ansible inventory of the nodes, reached by SSH through SSM. Write it with: terraform output -raw ansible_inventory > ansible/lab.ini"
  value = templatefile("${path.module}/templates/inventory.ini.tftpl", {
    region               = var.region
    control_plane_id     = module.compute.control_plane_instance_id
    worker_ids           = module.compute.worker_instance_ids
    ssh_private_key_file = var.ssh_private_key_file
  })
}

output "kubectl_tunnel" {
  description = "Keep this running in a second terminal: it forwards local port 6443 to the k3s API on the control plane, the address in the fetched kubeconfig."
  value       = "aws ssm start-session --region ${var.region} --target ${module.compute.control_plane_instance_id} --document-name AWS-StartPortForwardingSession --parameters '{\"portNumber\":[\"6443\"],\"localPortNumber\":[\"6443\"]}'"
}

output "app_urls" {
  description = "ShopLite in the browser: prod on port 80, dev on port 8080 of the ALB."
  value       = module.alb.urls
}

output "ecr_repository_urls" {
  description = "Where CI pushes each image (web, catalog-api, order-worker)."
  value       = module.ecr.repository_urls
}

output "ecr_registry" {
  description = "Registry host for docker login."
  value       = module.ecr.registry
}
