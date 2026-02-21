resource "aws_security_group" "umbra" {
  name        = "umbra-server"
  description = "Security group for umbra-server"
  vpc_id      = var.vpc_id

  ingress {
    description = "UDP relay traffic"
    from_port   = 52224
    to_port     = 52224
    protocol    = "udp"
    cidr_blocks = [for ip in var.allowed_ips : "${ip}/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge({
    Name = "umbra-server"
  }, local.iac_tags)
}
