output "instance_id" {
  value = aws_instance.umbra.id
}

output "public_ip" {
  value = aws_eip.umbra.public_ip
}

output "ecr_repository_url" {
  value = aws_ecr_repository.umbra.repository_url
}
