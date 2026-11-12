variable "name" {
  description = "Prefix for the Name tag of every resource, e.g. shoplite."
  type        = string
}

variable "vpc_cidr" {
  description = "Address range of the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "One public subnet per entry, each in its own Availability Zone (ALB and NAT Gateway live here)."
  type        = list(string)
  default     = ["10.0.0.0/24", "10.0.1.0/24"]

  validation {
    condition     = length(var.public_subnet_cidrs) >= 2
    error_message = "At least two public subnets are needed, so the VPC spans two Availability Zones."
  }
}

variable "private_subnet_cidrs" {
  description = "One private subnet per entry, in the same Availability Zones as the public ones (the Kubernetes nodes live here)."
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]

  validation {
    condition     = length(var.private_subnet_cidrs) >= 2
    error_message = "At least two private subnets are needed, so the VPC spans two Availability Zones."
  }

  validation {
    condition     = length(var.private_subnet_cidrs) == length(var.public_subnet_cidrs)
    error_message = "Give one private subnet for every public subnet (one of each per AZ)."
  }
}
