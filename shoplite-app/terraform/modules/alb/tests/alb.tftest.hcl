# Unit tests without AWS: the aws provider is mocked, and `command = apply` (offline) fills
# in the ids, so the links listener -> target group -> nodes can be checked.
# The provider still validates ARN arguments, so the load balancer and the two target
# groups get well-formed ARNs; the target groups get different ones, so a listener that
# points at the wrong environment would be caught.

mock_provider "aws" {
  mock_resource "aws_lb" {
    defaults = {
      arn      = "arn:aws:elasticloadbalancing:ap-southeast-1:123456789012:loadbalancer/app/shoplite/1111111111111111"
      dns_name = "shoplite-1234567890.ap-southeast-1.elb.amazonaws.com"
    }
  }
}

override_resource {
  target = aws_lb_target_group.ingress["prod"]
  values = {
    arn = "arn:aws:elasticloadbalancing:ap-southeast-1:123456789012:targetgroup/shoplite-prod/2222222222222222"
  }
}

override_resource {
  target = aws_lb_target_group.ingress["dev"]
  values = {
    arn = "arn:aws:elasticloadbalancing:ap-southeast-1:123456789012:targetgroup/shoplite-dev/3333333333333333"
  }
}

variables {
  name                   = "shoplite"
  vpc_id                 = "vpc-0123456789abcdef0"
  public_subnet_ids      = ["subnet-pub-a", "subnet-pub-b"]
  node_security_group_id = "sg-nodes"
  target_instance_ids    = ["i-worker1", "i-worker2"]
}

run "alb_is_public_in_the_public_subnets" {
  command = apply

  assert {
    condition     = aws_lb.this.load_balancer_type == "application" && !aws_lb.this.internal
    error_message = "It must be an internet-facing Application Load Balancer."
  }

  assert {
    condition     = aws_lb.this.subnets == toset(["subnet-pub-a", "subnet-pub-b"])
    error_message = "The ALB must sit in the public subnets of both AZs."
  }

  assert {
    condition     = aws_lb.this.security_groups == toset([aws_security_group.alb.id])
    error_message = "The ALB must use its own security group."
  }
}

run "listeners_forward_to_the_ingress_node_ports" {
  command = apply

  assert {
    condition = alltrue([
      aws_lb_listener.http["prod"].port == 80,
      aws_lb_listener.http["prod"].default_action[0].type == "forward",
      aws_lb_listener.http["prod"].default_action[0].target_group_arn == aws_lb_target_group.ingress["prod"].arn,
      aws_lb_target_group.ingress["prod"].port == 30080,
    ])
    error_message = "Port 80 must forward to the prod NodePort 30080."
  }

  assert {
    condition = alltrue([
      aws_lb_listener.http["dev"].port == 8080,
      aws_lb_listener.http["dev"].default_action[0].target_group_arn == aws_lb_target_group.ingress["dev"].arn,
      aws_lb_target_group.ingress["dev"].port == 30081,
    ])
    error_message = "Port 8080 must forward to the dev NodePort 30081."
  }

  assert {
    condition     = alltrue([for l in aws_lb_listener.http : l.load_balancer_arn == aws_lb.this.arn && l.protocol == "HTTP"])
    error_message = "Both listeners must be HTTP listeners of this ALB."
  }
}

run "both_workers_are_targets_of_both_environments" {
  command = apply

  assert {
    condition     = length(aws_lb_target_group_attachment.ingress) == 4
    error_message = "Two environments times two workers must give four attachments."
  }

  assert {
    condition = alltrue([
      for env in ["prod", "dev"] :
      toset([for a in aws_lb_target_group_attachment.ingress : a.target_id if a.target_group_arn == aws_lb_target_group.ingress[env].arn]) == toset(["i-worker1", "i-worker2"])
    ])
    error_message = "Every environment's target group must hold both workers."
  }

  assert {
    condition     = alltrue([for a in aws_lb_target_group_attachment.ingress : a.port == (a.target_group_arn == aws_lb_target_group.ingress["prod"].arn ? 30080 : 30081)])
    error_message = "Each attachment must use its environment's NodePort."
  }
}

run "health_check_asks_traefik" {
  command = apply

  assert {
    condition = alltrue([
      for tg in aws_lb_target_group.ingress :
      tg.health_check[0].path == "/ping" && tg.health_check[0].matcher == "200" && tg.target_type == "instance" && tg.protocol == "HTTP"
    ])
    error_message = "The target groups must check Traefik's /ping on the instances and expect 200."
  }
}

run "only_the_alb_reaches_the_node_ports" {
  command = apply

  assert {
    condition = alltrue([
      for r in aws_vpc_security_group_ingress_rule.nodes_from_alb :
      r.security_group_id == "sg-nodes" && r.referenced_security_group_id == aws_security_group.alb.id && r.cidr_ipv4 == null
    ])
    error_message = "The nodes may accept the ingress ports only from the ALB's security group."
  }

  assert {
    condition = { for k, r in aws_vpc_security_group_ingress_rule.nodes_from_alb : k => "${r.from_port}-${r.to_port}" } == {
      prod = "30080-30080"
      dev  = "30081-30081"
    }
    error_message = "Only the two ingress NodePorts may be opened on the nodes."
  }

  assert {
    condition     = alltrue([for r in aws_vpc_security_group_egress_rule.alb_to_nodes : r.referenced_security_group_id == "sg-nodes" && r.cidr_ipv4 == null])
    error_message = "The ALB may send traffic only to the nodes."
  }

  assert {
    condition = { for k, r in aws_vpc_security_group_ingress_rule.alb_from_internet : k => "${r.cidr_ipv4} ${r.from_port}-${r.to_port}" } == {
      prod = "0.0.0.0/0 80-80"
      dev  = "0.0.0.0/0 8080-8080"
    }
    error_message = "From the internet the ALB may accept only ports 80 and 8080."
  }
}

run "urls_for_both_environments" {
  command = apply

  assert {
    condition     = output.urls["prod"] == "http://${aws_lb.this.dns_name}" && output.urls["dev"] == "http://${aws_lb.this.dns_name}:8080"
    error_message = "prod must be on the plain ALB URL and dev on port 8080."
  }
}

run "rejects_a_node_port_outside_the_kubernetes_range" {
  command = plan

  variables {
    listeners = {
      prod = { port = 80, node_port = 8080 }
    }
  }

  expect_failures = [var.listeners]
}

run "rejects_a_single_subnet" {
  command = plan

  variables {
    public_subnet_ids = ["subnet-pub-a"]
  }

  expect_failures = [var.public_subnet_ids]
}
