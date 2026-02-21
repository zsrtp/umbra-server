resource "aws_ecr_repository" "umbra" {
  name                 = "umbra-server"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true
  tags                 = local.iac_tags
}

resource "aws_ecr_lifecycle_policy" "umbra" {
  repository = aws_ecr_repository.umbra.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 5 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 5
      }
      action = {
        type = "expire"
      }
    }]
  })
}
