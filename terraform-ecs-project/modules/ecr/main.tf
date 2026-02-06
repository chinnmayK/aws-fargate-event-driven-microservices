# ============================================================
# ECR MODULE
# File: modules/ecr/main.tf
# ============================================================

# ------------------------------------------------------------
# Input Variables
# ------------------------------------------------------------
# List of microservice names for which ECR repositories
# will be created. Each service gets its own repository.
variable "service_names" {
  type    = list(string)
  default = ["customer", "products", "shopping"]
}

# ------------------------------------------------------------
# ECR Repositories
# ------------------------------------------------------------
# Creates one Amazon ECR repository per microservice.
# These repositories store Docker images used by ECS services.
resource "aws_ecr_repository" "repo" {
  count                = length(var.service_names)
  name                 = var.service_names[count.index]

  # Allows image tags to be overwritten (useful for CI/CD pipelines)
  image_tag_mutability = "MUTABLE"

  # Allows Terraform to delete repositories even if images exist
  force_delete = true

  # Enables vulnerability scanning on image push
  image_scanning_configuration {
    scan_on_push = true
  }
}

# ------------------------------------------------------------
# Outputs
# ------------------------------------------------------------
# List of ECR repository URLs, one per microservice.
# Used by CI/CD pipelines and ECS task definitions.
output "repository_urls" {
  value = aws_ecr_repository.repo[*].repository_url
}
