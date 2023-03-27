resource "aws_ecr_repository" "frontend" {
  name                 = "${var.name}-${var.environment}-frontend"
  image_tag_mutability = "MUTABLE"
  count                = var.frontend ? 1 : 0
  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "backend" {
  name                 = "${var.name}-${var.environment}-backend"
  image_tag_mutability = "MUTABLE"
  count                = var.backend ? 1 : 0
  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "backend" {
  repository = aws_ecr_repository.backend[0].name
  count      = var.backend ? 1 : 0
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "keep last 10 images"
      action = {
        type = "expire"
      }
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
    }]
  })
}

resource "aws_ecr_lifecycle_policy" "frontend" {
  repository = aws_ecr_repository.frontend[0].name
  count      = var.frontend ? 1 : 0
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "keep last 10 images"
      action = {
        type = "expire"
      }
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
    }]
  })
}

output "aws_ecr_repository_url_frontend" {
  value = aws_ecr_repository.frontend[0].repository_url
}

output "aws_ecr_repository_url_backend" {
  value = aws_ecr_repository.backend[0].repository_url
}
