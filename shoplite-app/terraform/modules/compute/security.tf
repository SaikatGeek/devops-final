# Least-privilege security groups for the Kubernetes nodes (question 4b).
# Nothing from the internet may connect, not even SSH: admin access goes through SSM
# Session Manager, whose agent only makes outgoing connections. Between nodes only the
# ports k3s and the monitoring need are open, and only for other nodes. The ALB's access
# to the ingress ports is added by the alb module.

resource "aws_security_group" "nodes" {
  name        = "${var.name}-nodes"
  description = "Kubernetes nodes: reachable only from other nodes (and the ALB on the ingress ports)"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.name}-nodes" }
}

locals {
  # Every node to every node.
  node_ports = {
    flannel_vxlan = { protocol = "udp", port = 8472, description = "Flannel VXLAN: the pod network between nodes" }
    kubelet       = { protocol = "tcp", port = 10250, description = "kubelet API: logs, exec, resource metrics" }
    node_exporter = { protocol = "tcp", port = 9100, description = "Prometheus node-exporter on every node (question 6)" }
  }
}

resource "aws_vpc_security_group_ingress_rule" "node_to_node" {
  for_each                     = local.node_ports
  security_group_id            = aws_security_group.nodes.id
  referenced_security_group_id = aws_security_group.nodes.id
  ip_protocol                  = each.value.protocol
  from_port                    = each.value.port
  to_port                      = each.value.port
  description                  = each.value.description
}

resource "aws_vpc_security_group_egress_rule" "nodes_out" {
  security_group_id = aws_security_group.nodes.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Outgoing only, through the NAT Gateway: image pulls, SSM, package updates"
}

# The control plane additionally serves the Kubernetes API, to the nodes only. kubectl
# from outside reaches it through an SSM port forward, so no rule is needed for that.
resource "aws_security_group" "control_plane" {
  name        = "${var.name}-control-plane"
  description = "k3s server: the Kubernetes API, reachable only from the nodes"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.name}-control-plane" }
}

resource "aws_vpc_security_group_ingress_rule" "api_from_nodes" {
  security_group_id            = aws_security_group.control_plane.id
  referenced_security_group_id = aws_security_group.nodes.id
  ip_protocol                  = "tcp"
  from_port                    = 6443
  to_port                      = 6443
  description                  = "k3s supervisor and Kubernetes API, for the agents"
}
