# Kubernetes nodes (question 4c): one control-plane and the workers, all in private
# subnets without public IPs. Admin access is through SSM Session Manager (the preferred
# option in the question), so no bastion host and no open SSH port are needed.

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

# The nodes' identity: only what they need, nothing more.
resource "aws_iam_role" "nodes" {
  name = "${var.name}-node"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

locals {
  node_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",       # SSM Session Manager: admin access
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly", # pull (never push) images from ECR
  ]
}

resource "aws_iam_role_policy_attachment" "nodes" {
  for_each   = toset(local.node_policy_arns)
  role       = aws_iam_role.nodes.name
  policy_arn = each.value
}

resource "aws_iam_instance_profile" "nodes" {
  name = "${var.name}-node"
  role = aws_iam_role.nodes.name
}

# Ansible (question 4g) logs in with SSH tunnelled through SSM Session Manager
# (AWS-StartSSHSession): the SSM agent connects to port 22 on the instance itself, so no
# security group opens 22 and the nodes keep no public IP. The key pair only puts this
# public key into the ubuntu user's authorized_keys.
resource "aws_key_pair" "nodes" {
  key_name   = "${var.name}-nodes"
  public_key = var.ssh_public_key
}

locals {
  # The same for every node.
  node = {
    ami                  = data.aws_ami.ubuntu.id
    iam_instance_profile = aws_iam_instance_profile.nodes.name
    key_name             = aws_key_pair.nodes.key_name
  }
}

resource "aws_instance" "control_plane" {
  ami                         = local.node.ami
  instance_type               = var.control_plane_instance_type
  subnet_id                   = var.private_subnet_ids[0]
  vpc_security_group_ids      = [aws_security_group.nodes.id, aws_security_group.control_plane.id]
  iam_instance_profile        = local.node.iam_instance_profile
  key_name                    = local.node.key_name
  associate_public_ip_address = false

  # IMDSv2 only, one hop: containers cannot read the node's AWS credentials.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = var.root_volume_size
    encrypted   = true
  }

  tags = { Name = "${var.name}-control-plane", role = "control-plane" }
}

resource "aws_instance" "worker" {
  count = var.worker_count

  ami           = local.node.ami
  instance_type = var.worker_instance_type
  # Worker i goes into subnet i (round robin), so the workers are spread over the AZs.
  subnet_id                   = var.private_subnet_ids[count.index % length(var.private_subnet_ids)]
  vpc_security_group_ids      = [aws_security_group.nodes.id]
  iam_instance_profile        = local.node.iam_instance_profile
  key_name                    = local.node.key_name
  associate_public_ip_address = false

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = var.root_volume_size
    encrypted   = true
  }

  tags = { Name = "${var.name}-worker-${count.index + 1}", role = "worker" }
}
