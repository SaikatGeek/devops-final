output "control_plane_instance_id" {
  description = "Instance id of the k3s server (for SSM: aws ssm start-session --target <id>)."
  value       = aws_instance.control_plane.id
}

output "control_plane_private_ip" {
  description = "Private IP of the k3s server; the agents join it on port 6443."
  value       = aws_instance.control_plane.private_ip
}

output "worker_instance_ids" {
  description = "Instance ids of the k3s agents."
  value       = aws_instance.worker[*].id
}

output "worker_private_ips" {
  description = "Private IPs of the k3s agents."
  value       = aws_instance.worker[*].private_ip
}

output "node_security_group_id" {
  description = "Security group of every node; the alb module lets the ALB in on the ingress ports."
  value       = aws_security_group.nodes.id
}
