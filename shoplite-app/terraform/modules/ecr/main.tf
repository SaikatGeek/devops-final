# One ECR repository per application image (question 4e): shoplite/web,
# shoplite/catalog-api and shoplite/order-worker. GitHub Actions pushes the images here
# (question 7) and the Kubernetes nodes pull them with their pull-only role.

resource "aws_ecr_repository" "app" {
  for_each = toset(var.repositories)
  name     = "${var.name}/${each.key}"

  # The final `terraform destroy` (cost guard) must remove a repository that still holds
  # images; without this, AWS refuses to delete it.
  force_delete = true
}
