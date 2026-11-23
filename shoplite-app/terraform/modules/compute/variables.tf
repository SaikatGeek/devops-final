variable "name" {
  description = "Prefix for names and Name tags, e.g. shoplite."
  type        = string
}

variable "vpc_id" {
  description = "VPC of the nodes."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnets for the nodes, one per AZ; the workers are spread over them."
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_ids) >= 1
    error_message = "At least one private subnet is needed."
  }
}

variable "public_subnet_id" {
  description = "Public subnet for the bastion host, the only instance with a public IP."
  type        = string
}

variable "admin_cidr" {
  description = "The admin's (lab terminal's) public IP as a CIDR, e.g. 203.0.113.10/32: the only source that may reach the bastion's SSH port."
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

variable "bastion_instance_type" {
  description = "EC2 type of the bastion host; it only relays SSH."
  type        = string
  default     = "t3.micro"
}

variable "ssh_public_key" {
  description = "Public SSH key for the ubuntu user on every node and on the bastion; Ansible logs in with it through the bastion. Pass it as TF_VAR_ssh_public_key."
  type        = string

  validation {
    condition     = can(regex("^(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp(256|384|521)) ", var.ssh_public_key))
    error_message = "ssh_public_key must be an OpenSSH public key (ssh-ed25519 ..., ssh-rsa ... or ecdsa-sha2-...)."
  }
}

variable "control_plane_instance_type" {
  description = "EC2 type of the k3s server (control plane)."
  type        = string
  default     = "t3.medium"
}

variable "worker_instance_type" {
  description = "EC2 type of the k3s agents (workers); they also run the monitoring stack."
  type        = string
  default     = "t3.large"
}

variable "worker_count" {
  description = "Number of worker nodes."
  type        = number
  default     = 2

  validation {
    condition     = var.worker_count >= 1
    error_message = "At least one worker is needed."
  }
}

variable "root_volume_size" {
  description = "Root disk of every node in GiB (container images, Prometheus and Loki data)."
  type        = number
  default     = 30
}
