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
  description = "Instance id of the k3s server."
  value       = module.compute.control_plane_instance_id
}

output "worker_instance_ids" {
  description = "Instance ids of the k3s agents."
  value       = module.compute.worker_instance_ids
}

locals {
  # Every SSH connection to a node goes through the bastion host, with the same key.
  bastion_proxy   = "ssh -i ${var.ssh_private_key_file} -o StrictHostKeyChecking=accept-new -W %h:%p ubuntu@${module.compute.bastion_public_ip}"
  ssh_via_bastion = "ssh -i ${var.ssh_private_key_file} -o StrictHostKeyChecking=accept-new -o ProxyCommand=\"${local.bastion_proxy}\""
}

output "bastion_public_ip" {
  description = "Public IP of the bastion host, the only way in to the nodes (SSH from admin_cidr)."
  value       = module.compute.bastion_public_ip
}

output "ssh_via_bastion" {
  description = "Opens a shell on a node through the bastion: eval \"$(terraform -chdir=terraform output -raw ssh_via_bastion) ubuntu@<the node's ansible_host from ansible/lab.ini>\""
  value       = local.ssh_via_bastion
}

output "ansible_inventory" {
  description = "Ansible inventory of the nodes, reached by SSH through the bastion. Write it with: terraform output -raw ansible_inventory > ansible/lab.ini"
  value = templatefile("${path.module}/templates/inventory.ini.tftpl", {
    control_plane_ip     = module.compute.control_plane_private_ip
    worker_ips           = module.compute.worker_private_ips
    ssh_private_key_file = var.ssh_private_key_file
    proxy_command        = local.bastion_proxy
  })
}

output "kubectl_tunnel" {
  description = "Keep this running in a second terminal: over SSH through the bastion, it forwards local port 6443, the address in the fetched kubeconfig, to the k3s API on the control plane."
  value       = "${local.ssh_via_bastion} -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 -N -L 6443:127.0.0.1:6443 ubuntu@${module.compute.control_plane_private_ip}"
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

output "ci_role_arn" {
  description = "The role GitHub Actions takes through OIDC to push the images (role-to-assume in shoplite-app's workflows)."
  value       = module.github_oidc.role_arn
}

output "ci_plan_role_arn" {
  description = "The read-only role the pull-request pipeline takes through OIDC for terraform plan (variable AWS_PLAN_ROLE_ARN)."
  value       = module.github_oidc.plan_role_arn
}
