# Unit tests without AWS: the aws provider is mocked. `command = apply` makes the mock fill
# in ids, so the links between resources (subnet -> VPC, route -> gateway) can be checked.

mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = {
      names = ["ap-southeast-1a", "ap-southeast-1b", "ap-southeast-1c"]
    }
  }
}

variables {
  name = "shoplite"
}

run "two_public_and_two_private_subnets_over_two_azs" {
  command = apply

  assert {
    condition     = aws_vpc.this.cidr_block == "10.0.0.0/16"
    error_message = "The VPC must be 10.0.0.0/16."
  }

  assert {
    condition     = length(aws_subnet.public) == 2 && length(aws_subnet.private) == 2
    error_message = "There must be two public and two private subnets."
  }

  assert {
    condition = alltrue([
      aws_subnet.public[*].availability_zone == ["ap-southeast-1a", "ap-southeast-1b"],
      aws_subnet.private[*].availability_zone == ["ap-southeast-1a", "ap-southeast-1b"],
    ])
    error_message = "Subnet i of each kind must be in AZ i, so the VPC spans two AZs."
  }

  assert {
    condition = alltrue([
      aws_subnet.public[*].cidr_block == ["10.0.0.0/24", "10.0.1.0/24"],
      aws_subnet.private[*].cidr_block == ["10.0.10.0/24", "10.0.11.0/24"],
    ])
    error_message = "The subnets must use the default address ranges."
  }

  assert {
    condition     = alltrue([for s in concat(aws_subnet.public, aws_subnet.private) : s.vpc_id == aws_vpc.this.id])
    error_message = "Every subnet must be in the VPC."
  }

  assert {
    condition     = alltrue([for s in concat(aws_subnet.public, aws_subnet.private) : !s.map_public_ip_on_launch])
    error_message = "No subnet may give instances a public IP automatically."
  }
}

run "public_subnets_reach_the_internet_through_the_internet_gateway" {
  command = apply

  assert {
    condition     = aws_internet_gateway.this.vpc_id == aws_vpc.this.id
    error_message = "The Internet Gateway must be attached to the VPC."
  }

  assert {
    condition = alltrue([
      aws_route.public_internet.route_table_id == aws_route_table.public.id,
      aws_route.public_internet.destination_cidr_block == "0.0.0.0/0",
      aws_route.public_internet.gateway_id == aws_internet_gateway.this.id,
    ])
    error_message = "The public route table must send 0.0.0.0/0 to the Internet Gateway."
  }

  assert {
    condition = alltrue([
      aws_route_table_association.public[*].subnet_id == aws_subnet.public[*].id,
      alltrue([for a in aws_route_table_association.public : a.route_table_id == aws_route_table.public.id]),
    ])
    error_message = "Every public subnet must use the public route table."
  }
}

run "private_subnets_go_out_only_through_the_nat_gateway" {
  command = apply

  assert {
    condition     = aws_nat_gateway.this.subnet_id == aws_subnet.public[0].id
    error_message = "The NAT Gateway must sit in a public subnet."
  }

  assert {
    condition     = aws_nat_gateway.this.allocation_id == aws_eip.nat.id && aws_eip.nat.domain == "vpc"
    error_message = "The NAT Gateway must use the Elastic IP."
  }

  assert {
    condition = alltrue([
      aws_route.private_internet.route_table_id == aws_route_table.private.id,
      aws_route.private_internet.destination_cidr_block == "0.0.0.0/0",
      aws_route.private_internet.nat_gateway_id == aws_nat_gateway.this.id,
    ])
    error_message = "The private route table must send 0.0.0.0/0 to the NAT Gateway."
  }

  assert {
    condition = alltrue([
      aws_route_table_association.private[*].subnet_id == aws_subnet.private[*].id,
      alltrue([for a in aws_route_table_association.private : a.route_table_id == aws_route_table.private.id]),
    ])
    error_message = "Every private subnet must use the private route table."
  }
}

run "resources_are_named" {
  command = plan

  assert {
    condition = alltrue([
      aws_vpc.this.tags["Name"] == "shoplite-vpc",
      [for s in aws_subnet.public : s.tags["Name"]] == ["shoplite-public-a", "shoplite-public-b"],
      [for s in aws_subnet.private : s.tags["Name"]] == ["shoplite-private-a", "shoplite-private-b"],
    ])
    error_message = "VPC and subnets must carry readable Name tags."
  }
}

run "three_azs_work_too" {
  command = plan

  variables {
    public_subnet_cidrs  = ["10.0.0.0/24", "10.0.1.0/24", "10.0.2.0/24"]
    private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24", "10.0.12.0/24"]
  }

  assert {
    condition     = aws_subnet.private[*].availability_zone == ["ap-southeast-1a", "ap-southeast-1b", "ap-southeast-1c"]
    error_message = "The module must be reusable with more AZs."
  }
}

run "rejects_a_single_az" {
  command = plan

  variables {
    public_subnet_cidrs  = ["10.0.0.0/24"]
    private_subnet_cidrs = ["10.0.10.0/24"]
  }

  # Only the public list reports: Terraform skips the checks of private_subnet_cidrs,
  # because one of them refers to the already invalid public_subnet_cidrs.
  expect_failures = [var.public_subnet_cidrs]
}

run "rejects_unequal_subnet_lists" {
  command = plan

  variables {
    private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24", "10.0.12.0/24"]
  }

  expect_failures = [var.private_subnet_cidrs]
}
