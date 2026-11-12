# The ALB's security group, and the one rule that lets it into the nodes (question 4b, 4d):
#   internet --80, 8080--> ALB --30080, 30081--> nodes (Traefik NodePorts)
# Nothing else from the ALB reaches the nodes, and nothing else from the internet reaches the ALB.

resource "aws_security_group" "alb" {
  name        = "${var.name}-alb"
  description = "ALB: HTTP from the internet, forwarded only to the ingress NodePorts of the nodes"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.name}-alb" }
}

resource "aws_vpc_security_group_ingress_rule" "alb_from_internet" {
  for_each          = var.listeners
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = each.value.port
  to_port           = each.value.port
  description       = "HTTP for ${each.key}, from anywhere"
}

resource "aws_vpc_security_group_egress_rule" "alb_to_nodes" {
  for_each                     = var.listeners
  security_group_id            = aws_security_group.alb.id
  referenced_security_group_id = var.node_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = each.value.node_port
  to_port                      = each.value.node_port
  description                  = "To the ${each.key} ingress NodePort on the nodes"
}

resource "aws_vpc_security_group_ingress_rule" "nodes_from_alb" {
  for_each                     = var.listeners
  security_group_id            = var.node_security_group_id
  referenced_security_group_id = aws_security_group.alb.id
  ip_protocol                  = "tcp"
  from_port                    = each.value.node_port
  to_port                      = each.value.node_port
  description                  = "${each.key} ingress NodePort, from the ALB only"
}
