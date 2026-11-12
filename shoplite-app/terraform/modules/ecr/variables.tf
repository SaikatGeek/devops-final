variable "name" {
  description = "Namespace of the repositories, e.g. shoplite gives shoplite/web."
  type        = string
}

variable "repositories" {
  description = "One repository per application image."
  type        = list(string)
  default     = ["web", "catalog-api", "order-worker"]

  validation {
    condition     = length(var.repositories) > 0 && length(distinct(var.repositories)) == length(var.repositories)
    error_message = "Give at least one repository, each name once."
  }

  validation {
    condition     = alltrue([for r in var.repositories : can(regex("^[a-z0-9]+([._-][a-z0-9]+)*$", r))])
    error_message = "Repository names may use lower-case letters, digits and . _ - between them."
  }
}
