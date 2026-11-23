variable "region" {
  description = "AWS region for everything ShopLite creates."
  type        = string
  default     = "ap-southeast-1"
}

variable "admin_cidr" {
  description = "The admin's (lab terminal's) public IP as a CIDR, e.g. 203.0.113.10/32: the only source that may reach the bastion's SSH port. Pass it as TF_VAR_admin_cidr."
  type        = string

  validation {
    condition     = can(cidrhost(var.admin_cidr, 0))
    error_message = "admin_cidr must be a CIDR range, e.g. 203.0.113.10/32."
  }

  validation {
    condition     = try(tonumber(split("/", var.admin_cidr)[1]) >= 24, false)
    error_message = "admin_cidr must be one address or a small range (/24 or narrower), never the whole internet."
  }
}

variable "ssh_public_key" {
  description = "Public SSH key for the ubuntu user on the nodes and the bastion; Ansible logs in with it through the bastion. Pass it as TF_VAR_ssh_public_key."
  type        = string

  validation {
    condition     = can(regex("^(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp(256|384|521)) ", var.ssh_public_key))
    error_message = "ssh_public_key must be an OpenSSH public key (ssh-ed25519 ..., ssh-rsa ... or ecdsa-sha2-...)."
  }
}

variable "ssh_private_key_file" {
  description = "Where the matching private key is on the machine that runs Ansible. Only written into the ansible_inventory output; Terraform never reads it."
  type        = string
  default     = "~/.ssh/shoplite"
}

variable "budget_alert_email" {
  description = "Where the USD 20 budget alarm goes. Personal, so never in Git: pass it as TF_VAR_budget_alert_email."
  type        = string

  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.budget_alert_email))
    error_message = "budget_alert_email must be an e-mail address."
  }
}
