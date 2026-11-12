variable "region" {
  description = "AWS region for everything ShopLite creates."
  type        = string
  default     = "ap-southeast-1"
}

variable "budget_alert_email" {
  description = "Where the USD 20 budget alarm goes. Personal, so never in Git: pass it as TF_VAR_budget_alert_email."
  type        = string

  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.budget_alert_email))
    error_message = "budget_alert_email must be an e-mail address."
  }
}
