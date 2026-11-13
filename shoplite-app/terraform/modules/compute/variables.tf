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

variable "ssh_public_key" {
  description = "Public SSH key for the ubuntu user on every node; Ansible logs in with it through SSM (port 22 stays closed). Pass it as TF_VAR_ssh_public_key."
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
