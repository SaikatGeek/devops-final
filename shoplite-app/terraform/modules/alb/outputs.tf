output "dns_name" {
  description = "Public DNS name of the ALB."
  value       = aws_lb.this.dns_name
}

output "urls" {
  description = "Browser URL of every environment, e.g. prod = http://<alb>, dev = http://<alb>:8080."
  value = {
    for env, l in var.listeners :
    env => l.port == 80 ? "http://${aws_lb.this.dns_name}" : "http://${aws_lb.this.dns_name}:${l.port}"
  }
}

output "security_group_id" {
  description = "Security group of the ALB."
  value       = aws_security_group.alb.id
}

output "target_group_arns" {
  description = "Target group of every environment (for checking target health)."
  value       = { for env, tg in aws_lb_target_group.ingress : env => tg.arn }
}
