# The Ubuntu server of question 3. It runs the Docker Compose stack (question 2's
# clean-machine checkpoint) and is hardened with linux/evidence/commands.md.
# It has a small VPC of its own (one public subnet, no NAT Gateway), so it needs neither
# the default VPC nor the main configuration, and it can be created first.
#
# Once per account run ../bootstrap (the state bucket), then from shoplite-app/:
#   terraform -chdir=terraform/q3-server init -backend-config="bucket=<state_bucket>" -backend-config="region=<region>"
#   export TF_VAR_admin_cidr="$(curl -s https://checkip.amazonaws.com)/32"
#   export TF_VAR_ssh_public_key="$(cat ~/.ssh/id_ed25519.pub)"
#   terraform -chdir=terraform/q3-server apply
# After grading: terraform -chdir=terraform/q3-server destroy (cost guard).

terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.73"
    }
  }
}

provider "aws" {
  region = var.region
  # Cost guard: every resource that supports tags gets project=shoplite.
  default_tags {
    tags = { project = "shoplite" }
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

# ---- network: one public subnet with a route to the internet ----

resource "aws_vpc" "q3" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "shoplite-q3" }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.q3.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, 0)
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = false # the server asks for its public IP itself
  tags                    = { Name = "shoplite-q3-public" }
}

resource "aws_internet_gateway" "q3" {
  vpc_id = aws_vpc.q3.id
  tags   = { Name = "shoplite-q3" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.q3.id
  tags   = { Name = "shoplite-q3-public" }
}

resource "aws_route" "internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.q3.id
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# ---- security group: the admin's IP only ----
# Port 8000 is open here on purpose: in 3.4 a program listens on it and the connection
# still times out, which proves that UFW on the server blocks it, not AWS.

resource "aws_security_group" "server" {
  name        = "shoplite-q3-server"
  description = "Question 3 server: SSH, HTTP, HTTPS and the firewall test port, from the admin only"
  vpc_id      = aws_vpc.q3.id
  tags        = { Name = "shoplite-q3-server" }
}

locals {
  admin_ports = {
    ssh   = { port = 22, description = "SSH (3.1)" }
    http  = { port = 80, description = "HTTP: the ShopLite page of the Compose stack" }
    https = { port = 443, description = "HTTPS (allowed by the firewall rules of 3.4)" }
    test  = { port = 8000, description = "Test port of 3.4: open here, so only UFW can block it" }
  }
}

resource "aws_vpc_security_group_ingress_rule" "admin" {
  for_each          = local.admin_ports
  security_group_id = aws_security_group.server.id
  cidr_ipv4         = var.admin_cidr
  ip_protocol       = "tcp"
  from_port         = each.value.port
  to_port           = each.value.port
  description       = each.value.description
}

resource "aws_vpc_security_group_egress_rule" "out" {
  security_group_id = aws_security_group.server.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Outgoing: packages, image pulls, git clone"
}

# ---- the server ----

resource "aws_key_pair" "admin" {
  key_name   = "shoplite-q3"
  public_key = var.ssh_public_key
}

# Ubuntu 24.04 LTS, the newest image Canonical (owner 099720109477) has published.
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "aws_instance" "server" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.server.id]
  key_name                    = aws_key_pair.admin.key_name
  associate_public_ip_address = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  # Room for Docker, the image builds and the backups.
  root_block_device {
    volume_type = "gp3"
    volume_size = 20
    encrypted   = true
  }

  tags = { Name = "shoplite-q3-server" }

  depends_on = [aws_route_table_association.public] # internet access from the first boot
}
