variable "name" {
  description = "Prefix for names and Name tags, e.g. shoplite."
  type        = string
}

variable "vpc_id" {
  description = "VPC of the ALB and the nodes."
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnets for the ALB, in at least two AZs."
  type        = list(string)

  validation {
    condition     = length(var.public_subnet_ids) >= 2
    error_message = "An ALB needs subnets in at least two Availability Zones."
  }
}

variable "node_security_group_id" {
  description = "Security group of the Kubernetes nodes; the ALB is let in on the ingress NodePorts only."
  type        = string
}

variable "target_instance_ids" {
  description = "Nodes that receive the ALB's traffic on the ingress NodePorts (the workers)."
  type        = list(string)
}

variable "listeners" {
  description = "One HTTP listener per environment: its public port and the ingress (Traefik) NodePort it forwards to."
  type = map(object({
    port      = number
    node_port = number
  }))
  default = {
    prod = { port = 80, node_port = 30080 }
    dev  = { port = 8080, node_port = 30081 }
  }

  validation {
    condition     = alltrue([for l in values(var.listeners) : l.node_port >= 30000 && l.node_port <= 32767])
    error_message = "node_port must be in Kubernetes' NodePort range, 30000-32767."
  }

  validation {
    condition     = length(distinct([for l in values(var.listeners) : l.port])) == length(var.listeners)
    error_message = "Every listener needs its own public port."
  }
}

variable "health_check_path" {
  description = "Path the ALB checks on the ingress NodePort; Traefik answers /ping with 200 when it is up."
  type        = string
  default     = "/ping"
}
