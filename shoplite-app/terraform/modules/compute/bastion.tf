# Admin access (question 4c) through a bastion host, the question's other option. The nodes
# are set up for SSM Session Manager, the preferred one (agent and role), but the lab
# account's organization policy denies it to the instances (an explicit deny on ssm,
# ec2messages and ssmmessages), so the sessions never connect.
#
# The bastion is the only instance with a public IP. Its SSH port admits only admin_cidr, it
# may connect only to the nodes' SSH port, and the nodes accept SSH only from it. It has no
# IAM role: it only relays SSH. Ansible (4g) and the kubectl tunnel go through it, with the
# same key as the nodes.

resource "aws_security_group" "bastion" {
  name        = "${var.name}-bastion"
  description = "Bastion host: SSH from the admin's address only, and on to the nodes"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.name}-bastion" }
}

resource "aws_vpc_security_group_ingress_rule" "ssh_from_admin" {
  security_group_id = aws_security_group.bastion.id
  cidr_ipv4         = var.admin_cidr
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  description       = "SSH from the admin's address only"
}

resource "aws_vpc_security_group_egress_rule" "ssh_to_nodes" {
  security_group_id            = aws_security_group.bastion.id
  referenced_security_group_id = aws_security_group.nodes.id
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
  description                  = "SSH on to the nodes, nothing else"
}

resource "aws_vpc_security_group_ingress_rule" "ssh_from_bastion" {
  security_group_id            = aws_security_group.nodes.id
  referenced_security_group_id = aws_security_group.bastion.id
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
  description                  = "SSH from the bastion host only: Ansible and the kubectl tunnel"
}

resource "aws_instance" "bastion" {
  ami                         = local.node.ami
  instance_type               = var.bastion_instance_type
  subnet_id                   = var.public_subnet_id
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  key_name                    = local.node.key_name
  associate_public_ip_address = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 10
    encrypted   = true
  }

  tags = { Name = "${var.name}-bastion", role = "bastion" }
}
