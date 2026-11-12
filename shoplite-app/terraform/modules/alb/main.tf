# Public Application Load Balancer in front of the Kubernetes ingress (question 4d).
# Traefik listens on a NodePort per environment on every node; the ALB has one HTTP
# listener per environment and forwards it to that NodePort on the target nodes:
#   :80   -> prod (namespace shoplite)      -> NodePort 30080
#   :8080 -> dev  (namespace shoplite-dev)  -> NodePort 30081
# No domain is available, so there is no Route 53 record; the ALB's DNS name is the URL.

resource "aws_lb" "this" {
  name               = var.name
  load_balancer_type = "application"
  internal           = false
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids
}

resource "aws_lb_target_group" "ingress" {
  for_each    = var.listeners
  name        = "${var.name}-${each.key}"
  vpc_id      = var.vpc_id
  target_type = "instance"
  protocol    = "HTTP"
  port        = each.value.node_port

  # Checks the ingress itself (Traefik's /ping), not one application behind it.
  health_check {
    path    = var.health_check_path
    matcher = "200"
  }
}

locals {
  # Every target node in every target group. Keyed by position, because instance ids
  # are only known after the instances exist.
  attachments = {
    for pair in setproduct(keys(var.listeners), range(length(var.target_instance_ids))) :
    "${pair[0]}-${pair[1]}" => { listener = pair[0], instance_index = pair[1] }
  }
}

resource "aws_lb_target_group_attachment" "ingress" {
  for_each         = local.attachments
  target_group_arn = aws_lb_target_group.ingress[each.value.listener].arn
  target_id        = var.target_instance_ids[each.value.instance_index]
  port             = var.listeners[each.value.listener].node_port
}

resource "aws_lb_listener" "http" {
  for_each          = var.listeners
  load_balancer_arn = aws_lb.this.arn
  port              = each.value.port
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ingress[each.key].arn
  }
}
