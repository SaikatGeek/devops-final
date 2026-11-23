variable "name" {
  description = "Prefix of the CI role's name, e.g. shoplite gives shoplite-github-ci."
  type        = string
}

variable "github_repository" {
  description = "The GitHub repository (owner/name): its main-branch runs may take the CI role, its pull-request runs the plan role."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9-]+/[A-Za-z0-9._-]+$", var.github_repository))
    error_message = "github_repository must be owner/name, e.g. SaikatGeek/shoplite-app (no URL, no wildcard)."
  }
}

# GitHub's tokens name a repository by its numeric IDs too (the immutable subject; see main.tf).
# Read them with: gh api repos/<owner>/<name> --jq '.owner.id, .id'
variable "github_owner_id" {
  description = "Numeric ID of the repository's owner (the API's owner.id), part of the tokens' subject."
  type        = string

  validation {
    condition     = can(regex("^[0-9]+$", var.github_owner_id))
    error_message = "github_owner_id must be the owner's numeric ID, e.g. 53232305 (digits only, no wildcard)."
  }
}

variable "github_repository_id" {
  description = "Numeric ID of the repository (the API's id), part of the tokens' subject."
  type        = string

  validation {
    condition     = can(regex("^[0-9]+$", var.github_repository_id))
    error_message = "github_repository_id must be the repository's numeric ID, e.g. 1454879820 (digits only, no wildcard)."
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
