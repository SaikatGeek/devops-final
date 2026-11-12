# Unit tests without AWS: the aws provider is mocked, and `command = apply` (offline) fills
# in the ids, so the links VPC -> subnet -> route -> instance can be checked.

mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = {
      names = ["ap-southeast-1a", "ap-southeast-1b"]
    }
  }

  mock_data "aws_ami" {
    defaults = {
      id = "ami-0123456789abcdef0"
    }
  }
}

variables {
  admin_cidr     = "203.0.113.10/32"
  ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIExampleKeyOnlyForTests admin@lab"
}

run "one_ubuntu_server_with_a_public_ip_in_its_own_vpc" {
  command = apply

  assert {
    condition     = aws_vpc.q3.cidr_block == "10.1.0.0/16" && aws_subnet.public.cidr_block == "10.1.0.0/24" && aws_subnet.public.vpc_id == aws_vpc.q3.id
    error_message = "The server needs its own VPC 10.1.0.0/16 with the public subnet 10.1.0.0/24."
  }

  assert {
    condition = alltrue([
      aws_instance.server.ami == "ami-0123456789abcdef0",
      aws_instance.server.instance_type == "t3.medium",
      aws_instance.server.subnet_id == aws_subnet.public.id,
      aws_instance.server.associate_public_ip_address,
    ])
    error_message = "One Ubuntu t3.medium server with a public IP in the public subnet."
  }

  assert {
    condition = alltrue([
      aws_internet_gateway.q3.vpc_id == aws_vpc.q3.id,
      aws_route.internet.route_table_id == aws_route_table.public.id,
      aws_route.internet.destination_cidr_block == "0.0.0.0/0",
      aws_route.internet.gateway_id == aws_internet_gateway.q3.id,
      aws_route_table_association.public.subnet_id == aws_subnet.public.id,
      aws_route_table_association.public.route_table_id == aws_route_table.public.id,
    ])
    error_message = "The public subnet must reach the internet through the VPC's Internet Gateway."
  }
}

run "only_the_admin_ip_reaches_22_80_443_and_8000" {
  command = apply

  assert {
    condition = { for k, r in aws_vpc_security_group_ingress_rule.admin : k => "${r.ip_protocol}/${r.from_port}-${r.to_port}" } == {
      ssh   = "tcp/22-22"
      http  = "tcp/80-80"
      https = "tcp/443-443"
      test  = "tcp/8000-8000"
    }
    error_message = "Only 22, 80, 443 and the test port 8000 may be open."
  }

  assert {
    condition     = alltrue([for r in aws_vpc_security_group_ingress_rule.admin : r.cidr_ipv4 == "203.0.113.10/32" && r.security_group_id == aws_security_group.server.id])
    error_message = "Every inbound rule must allow the admin's address only."
  }

  assert {
    condition     = aws_instance.server.vpc_security_group_ids == toset([aws_security_group.server.id])
    error_message = "The server must use this security group only."
  }
}

run "logs_in_with_the_given_key" {
  command = apply

  assert {
    condition     = aws_key_pair.admin.public_key == var.ssh_public_key && aws_instance.server.key_name == aws_key_pair.admin.key_name
    error_message = "The server must accept the admin's public key."
  }

  assert {
    condition     = output.ssh == "ssh ubuntu@${aws_instance.server.public_ip}"
    error_message = "The ssh output must show how to log in as ubuntu."
  }
}

run "imdsv2_only_and_encrypted_disk" {
  command = apply

  assert {
    condition     = aws_instance.server.metadata_options[0].http_tokens == "required" && aws_instance.server.metadata_options[0].http_put_response_hop_limit == 1
    error_message = "The server must require IMDSv2 with a hop limit of 1."
  }

  assert {
    condition     = aws_instance.server.root_block_device[0].encrypted && aws_instance.server.root_block_device[0].volume_size == 20
    error_message = "The server must have an encrypted 20 GiB disk."
  }
}

run "rejects_the_whole_internet_as_admin" {
  command = plan

  variables {
    admin_cidr = "0.0.0.0/0"
  }

  expect_failures = [var.admin_cidr]
}

run "rejects_something_that_is_not_a_cidr" {
  command = plan

  variables {
    admin_cidr = "my-laptop"
  }

  expect_failures = [var.admin_cidr]
}

run "rejects_something_that_is_not_a_public_key" {
  command = plan

  variables {
    ssh_public_key = "-----BEGIN OPENSSH PRIVATE KEY-----"
  }

  expect_failures = [var.ssh_public_key]
}
