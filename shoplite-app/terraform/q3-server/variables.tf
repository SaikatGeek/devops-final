variable "region" {
  description = "AWS region; the same as the state bucket's."
  type        = string
  default     = "ap-southeast-1"
}

variable "vpc_cidr" {
  description = "Address range of the server's own VPC (apart from the main VPC's 10.0.0.0/16)."
  type        = string
  default     = "10.1.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a CIDR range, e.g. 10.1.0.0/16."
  }
}

variable "admin_cidr" {
  description = "The admin's (lab terminal's) public IP as a CIDR, e.g. 203.0.113.10/32. The only source allowed in. Pass it as TF_VAR_admin_cidr."
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
  description = "Public SSH key for the ubuntu user, e.g. the contents of ~/.ssh/id_ed25519.pub. Pass it as TF_VAR_ssh_public_key."
  type        = string

  validation {
    condition     = can(regex("^(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp(256|384|521)) ", var.ssh_public_key))
    error_message = "ssh_public_key must be an OpenSSH public key (ssh-ed25519 ..., ssh-rsa ... or ecdsa-sha2-...)."
  }
}

variable "instance_type" {
  description = "EC2 type; it builds the images and runs the whole Docker Compose stack."
  type        = string
  default     = "t3.medium"
}
