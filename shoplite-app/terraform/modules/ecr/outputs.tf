output "repository_urls" {
  description = "Image URL of every repository, by short name (web, catalog-api, order-worker)."
  value       = { for r, repo in aws_ecr_repository.app : r => repo.repository_url }
}

output "repository_arns" {
  description = "ARN of every repository, by short name (for the CI role's push permission, question 7)."
  value       = { for r, repo in aws_ecr_repository.app : r => repo.arn }
}

output "registry" {
  description = "The registry host (<account>.dkr.ecr.<region>.amazonaws.com) for docker login and image names."
  value       = split("/", values(aws_ecr_repository.app)[0].repository_url)[0]
}
