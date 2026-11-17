output "role_arn" {
  description = "The CI role: the workflows give it to aws-actions/configure-aws-credentials as role-to-assume."
  value       = aws_iam_role.ci.arn
}

output "plan_role_arn" {
  description = "The plan role: the pull-request pipeline's role-to-assume for terraform plan."
  value       = aws_iam_role.plan.arn
}

output "oidc_provider_arn" {
  description = "AWS's trust in the tokens of GitHub Actions."
  value       = aws_iam_openid_connect_provider.github.arn
}
