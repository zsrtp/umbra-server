# Latest Amazon Linux 2023 ARM64 AMI
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-kernel-*-arm64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "umbra" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = "t4g.nano"
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.umbra.id]
  iam_instance_profile   = aws_iam_instance_profile.umbra.name

  root_block_device {
    volume_size = 20
  }

  user_data = <<-EOF
    #!/bin/bash
    dnf update -y
    dnf install -y docker
    systemctl enable docker
    systemctl start docker
  EOF

  tags = merge({
    Name = "umbra-server"
  }, local.iac_tags)

  lifecycle {
    ignore_changes = [ami, user_data]
  }
}

resource "aws_eip" "umbra" {
  domain   = "vpc"
  instance = aws_instance.umbra.id

  tags = merge({
    Name = "umbra-server"
  }, local.iac_tags)
}
