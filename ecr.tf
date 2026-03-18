# ============================================================
# ecr.tf — Elastic Container Registry
# ============================================================

resource "aws_ecr_repository" "app" {
  name                 = var.ecr_repo_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true   # Trivy-compatible: also scan with Trivy in the pipeline
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name = "${var.project_name}-ecr"
  }
}

# ── Lifecycle policy: keep only the 10 most recent images ────
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# ── Repository URL output (used by Jenkins pipeline) ─────────
output "ecr_repository_url" {
  description = "ECR repository URL for Docker push/pull"
  value       = aws_ecr_repository.app.repository_url
}
