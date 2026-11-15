variable "name" {
  description = "Prefix of the CI role's name, e.g. shoplite gives shoplite-github-ci."
  type        = string
}

variable "github_repository" {
  description = "The GitHub repository (owner/name) whose main-branch workflows may take the role."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9-]+/[A-Za-z0-9._-]+$", var.github_repository))
    error_message = "github_repository must be owner/name, e.g. SaikatGeek/shoplite-app (no URL, no wildcard)."
  }
}

variable "ecr_repository_arns" {
  description = "ARNs of the ECR repositories the role may push to."
  type        = list(string)

  validation {
    condition = length(var.ecr_repository_arns) > 0 && alltrue([
      for arn in var.ecr_repository_arns : can(regex("^arn:aws[a-z-]*:ecr:[a-z0-9-]+:[0-9]{12}:repository/[a-z0-9._/-]+$", arn))
    ])
    error_message = "Give at least one ECR repository ARN (arn:aws:ecr:<region>:<account>:repository/<name>), without wildcards."
  }
}
