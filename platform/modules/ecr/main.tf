# ECR Repositories - one per project
resource "aws_ecr_repository" "this" {
  for_each = toset(var.project_names)

  name                 = each.value
  image_tag_mutability = "MUTABLE"
  force_delete         = false

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = var.tags
}

# Lifecycle policy for each repository:
# - Keep all images suffixed with RELEASE
# - Keep only the last 5 images suffixed with SNAPSHOT
resource "aws_ecr_lifecycle_policy" "this" {
  for_each = aws_ecr_repository.this

  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep only the last 5 SNAPSHOT images"
        selection = {
          tagStatus      = "tagged"
          tagPatternList = ["*SNAPSHOT"]
          countType      = "imageCountMoreThan"
          countNumber    = 5
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
