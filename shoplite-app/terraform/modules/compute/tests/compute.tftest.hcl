# Unit tests without AWS: the aws provider is mocked, and `command = apply` (offline) fills
# in the ids, so the links between instances, security groups and the role can be checked.

mock_provider "aws" {
  mock_data "aws_ami" {
    defaults = {
      id = "ami-0123456789abcdef0"
    }
  }
}

variables {
  name               = "shoplite"
  vpc_id             = "vpc-0123456789abcdef0"
  private_subnet_ids = ["subnet-aaaa", "subnet-bbbb"]
  public_subnet_id   = "subnet-pppp"
  admin_cidr         = "203.0.113.10/32"
  ssh_public_key     = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl test"
}

run "one_control_plane_and_two_workers_in_the_private_subnets" {
  command = apply

  assert {
    condition     = length(aws_instance.worker) == 2
    error_message = "There must be two workers."
  }

  assert {
    condition     = aws_instance.control_plane.subnet_id == "subnet-aaaa" && aws_instance.worker[*].subnet_id == ["subnet-aaaa", "subnet-bbbb"]
    error_message = "All nodes must be in the private subnets, the workers spread over both AZs."
  }

  assert {
    condition     = aws_instance.control_plane.instance_type == "t3.medium" && aws_instance.worker[*].instance_type == ["t3.large", "t3.large"]
    error_message = "The control plane must be t3.medium and the workers t3.large."
  }

  assert {
    condition     = alltrue([for i in concat([aws_instance.control_plane], aws_instance.worker) : i.ami == "ami-0123456789abcdef0" && !i.associate_public_ip_address])
    error_message = "Every node must run the Ubuntu image and have no public IP."
  }
}

run "nothing_from_the_internet_reaches_the_nodes" {
  command = apply

  assert {
    condition = alltrue([
      for r in concat(values(aws_vpc_security_group_ingress_rule.node_to_node), [aws_vpc_security_group_ingress_rule.api_from_nodes]) :
      r.referenced_security_group_id == aws_security_group.nodes.id && r.cidr_ipv4 == null && r.cidr_ipv6 == null
    ])
    error_message = "Every inbound rule must allow only the nodes' own security group, never an address range."
  }

  assert {
    condition = { for k, r in aws_vpc_security_group_ingress_rule.node_to_node : k => "${r.ip_protocol}/${r.from_port}-${r.to_port}" } == {
      flannel_vxlan = "udp/8472-8472"
      kubelet       = "tcp/10250-10250"
      node_exporter = "tcp/9100-9100"
    }
    error_message = "Between nodes only 8472/udp, 10250/tcp and 9100/tcp may be open."
  }

  assert {
    condition = !anytrue([
      for r in concat(values(aws_vpc_security_group_ingress_rule.node_to_node), [aws_vpc_security_group_ingress_rule.api_from_nodes]) :
      r.from_port <= 22 && 22 <= r.to_port
    ])
    error_message = "No rule between the nodes may open SSH (22): it comes only from the bastion."
  }

  assert {
    condition = alltrue([
      aws_vpc_security_group_ingress_rule.ssh_from_bastion.security_group_id == aws_security_group.nodes.id,
      aws_vpc_security_group_ingress_rule.ssh_from_bastion.referenced_security_group_id == aws_security_group.bastion.id,
      aws_vpc_security_group_ingress_rule.ssh_from_bastion.cidr_ipv4 == null,
      aws_vpc_security_group_ingress_rule.ssh_from_bastion.ip_protocol == "tcp",
      aws_vpc_security_group_ingress_rule.ssh_from_bastion.from_port == 22,
      aws_vpc_security_group_ingress_rule.ssh_from_bastion.to_port == 22,
    ])
    error_message = "The nodes must accept SSH (22) only from the bastion's security group."
  }
}

run "the_bastion_is_the_only_way_in" {
  command = apply

  assert {
    condition = alltrue([
      aws_instance.bastion.subnet_id == "subnet-pppp",
      aws_instance.bastion.associate_public_ip_address,
      aws_instance.bastion.instance_type == "t3.micro",
      aws_instance.bastion.ami == "ami-0123456789abcdef0",
      aws_instance.bastion.vpc_security_group_ids == toset([aws_security_group.bastion.id]),
    ])
    error_message = "The bastion must be a t3.micro with a public IP in the public subnet, in the bastion group only."
  }

  assert {
    condition = alltrue([
      aws_vpc_security_group_ingress_rule.ssh_from_admin.security_group_id == aws_security_group.bastion.id,
      aws_vpc_security_group_ingress_rule.ssh_from_admin.cidr_ipv4 == "203.0.113.10/32",
      aws_vpc_security_group_ingress_rule.ssh_from_admin.referenced_security_group_id == null,
      aws_vpc_security_group_ingress_rule.ssh_from_admin.ip_protocol == "tcp",
      aws_vpc_security_group_ingress_rule.ssh_from_admin.from_port == 22,
      aws_vpc_security_group_ingress_rule.ssh_from_admin.to_port == 22,
    ])
    error_message = "The bastion must accept only SSH (22), only from admin_cidr."
  }

  assert {
    condition = alltrue([
      aws_vpc_security_group_egress_rule.ssh_to_nodes.security_group_id == aws_security_group.bastion.id,
      aws_vpc_security_group_egress_rule.ssh_to_nodes.referenced_security_group_id == aws_security_group.nodes.id,
      aws_vpc_security_group_egress_rule.ssh_to_nodes.cidr_ipv4 == null,
      aws_vpc_security_group_egress_rule.ssh_to_nodes.ip_protocol == "tcp",
      aws_vpc_security_group_egress_rule.ssh_to_nodes.from_port == 22,
      aws_vpc_security_group_egress_rule.ssh_to_nodes.to_port == 22,
    ])
    error_message = "The bastion may connect only to the nodes' SSH port."
  }

  assert {
    condition = alltrue([
      aws_instance.bastion.metadata_options[0].http_tokens == "required",
      aws_instance.bastion.metadata_options[0].http_put_response_hop_limit == 1,
      aws_instance.bastion.root_block_device[0].encrypted,
      aws_instance.bastion.root_block_device[0].volume_type == "gp3",
    ])
    error_message = "The bastion must require IMDSv2 and have an encrypted gp3 disk."
  }
}

run "rejects_an_admin_cidr_wider_than_24" {
  command = plan

  variables {
    admin_cidr = "0.0.0.0/0"
  }

  expect_failures = [var.admin_cidr]
}

run "only_the_control_plane_serves_the_kubernetes_api" {
  command = apply

  assert {
    condition = alltrue([
      aws_vpc_security_group_ingress_rule.api_from_nodes.security_group_id == aws_security_group.control_plane.id,
      aws_vpc_security_group_ingress_rule.api_from_nodes.ip_protocol == "tcp",
      aws_vpc_security_group_ingress_rule.api_from_nodes.from_port == 6443,
      aws_vpc_security_group_ingress_rule.api_from_nodes.to_port == 6443,
    ])
    error_message = "Port 6443 must be open on the control-plane group, for the nodes only."
  }

  assert {
    condition     = aws_instance.control_plane.vpc_security_group_ids == toset([aws_security_group.nodes.id, aws_security_group.control_plane.id])
    error_message = "The control plane must be in the node and the control-plane groups."
  }

  assert {
    condition     = alltrue([for w in aws_instance.worker : w.vpc_security_group_ids == toset([aws_security_group.nodes.id])])
    error_message = "The workers must be in the node group only."
  }
}

run "node_role_allows_only_ssm_and_ecr_pull" {
  command = apply

  assert {
    condition     = jsondecode(aws_iam_role.nodes.assume_role_policy).Statement[0].Principal.Service == "ec2.amazonaws.com"
    error_message = "Only EC2 instances may take the node role."
  }

  assert {
    condition = toset([for a in aws_iam_role_policy_attachment.nodes : a.policy_arn]) == toset([
      "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
      "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly",
    ])
    error_message = "The node role must have exactly the SSM and the ECR pull-only policies."
  }

  assert {
    condition     = alltrue([for i in concat([aws_instance.control_plane], aws_instance.worker) : i.iam_instance_profile == aws_iam_instance_profile.nodes.name])
    error_message = "Every node must use the node instance profile."
  }
}

run "imdsv2_only_and_encrypted_disks" {
  command = apply

  assert {
    condition = alltrue([
      for i in concat([aws_instance.control_plane], aws_instance.worker) :
      i.metadata_options[0].http_tokens == "required" && i.metadata_options[0].http_put_response_hop_limit == 1
    ])
    error_message = "Every node must require IMDSv2 with a hop limit of 1."
  }

  assert {
    condition = alltrue([
      for i in concat([aws_instance.control_plane], aws_instance.worker) :
      i.root_block_device[0].encrypted && i.root_block_device[0].volume_type == "gp3" && i.root_block_device[0].volume_size == 30
    ])
    error_message = "Every node must have an encrypted 30 GiB gp3 root disk."
  }
}

run "every_node_and_the_bastion_get_the_key" {
  command = apply

  assert {
    condition     = aws_key_pair.nodes.key_name == "shoplite-nodes" && aws_key_pair.nodes.public_key == var.ssh_public_key
    error_message = "The key pair must hold ssh_public_key."
  }

  assert {
    condition     = alltrue([for i in concat([aws_instance.control_plane, aws_instance.bastion], aws_instance.worker) : i.key_name == aws_key_pair.nodes.key_name])
    error_message = "Every node and the bastion must get the key pair, so Ansible can log in through the bastion."
  }
}

run "rejects_a_value_that_is_not_an_ssh_public_key" {
  command = plan

  variables {
    ssh_public_key = "my-secret-password"
  }

  expect_failures = [var.ssh_public_key]
}

run "worker_count_and_type_can_change" {
  command = plan

  variables {
    worker_count         = 3
    worker_instance_type = "t3.medium"
  }

  assert {
    condition     = aws_instance.worker[*].subnet_id == ["subnet-aaaa", "subnet-bbbb", "subnet-aaaa"]
    error_message = "Extra workers must go round robin over the subnets."
  }

  assert {
    condition     = aws_instance.worker[2].instance_type == "t3.medium"
    error_message = "The worker type must follow the variable (fallback when the lab has no t3.large)."
  }
}

run "rejects_zero_workers" {
  command = plan

  variables {
    worker_count = 0
  }

  expect_failures = [var.worker_count]
}
