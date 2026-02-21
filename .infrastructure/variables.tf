variable "allowed_ips" {
  description = "External IP addresses to allow access from"
  type        = list(string)
}

variable "vpc_id" {
  description = "VPC ID to deploy into"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID to deploy into"
  type        = string
}

variable "aws_account_id" {
  description = "AWS account ID"
  type        = string
}

variable "tf_state_bucket" {
  description = "S3 bucket for terraform state"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "image_tag" {
  description = "Docker image tag to deploy"
  type        = string
  default     = "latest"
}
