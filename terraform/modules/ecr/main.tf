locals {
  name_prefix = "petclinic-${var.environment}"
  common_tags = merge(
    {
      Project     = "petclinic"
      Environment = var.environment
      ManagedBy   = "terraform"
    },
    var.tags
  )
}

# ---------------------------------------------------------------------------
# ECR Repositories
# ---------------------------------------------------------------------------
resource "aws_ecr_repository" "service" {
  for_each = toset(var.services)

  name                 = "${local.name_prefix}/${each.value}"
  image_tag_mutability = var.environment == "prod" ? "IMMUTABLE" : "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}/${each.value}" })
}

# ---------------------------------------------------------------------------
# Lifecycle Policy — keep last 10 tagged images, expire untagged after 7 days
# ---------------------------------------------------------------------------
resource "aws_ecr_lifecycle_policy" "service" {
  for_each = toset(var.services)

  repository = aws_ecr_repository.service[each.value].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images after 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Keep last 10 tagged images"
        selection = {
          tagStatus      = "tagged"
          tagPatternList = ["*"]
          countType      = "imageCountMoreThan"
          countNumber    = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
