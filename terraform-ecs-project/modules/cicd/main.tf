# modules/cicd/main.tf

# 1. S3 Bucket for Pipeline Artifacts
resource "aws_s3_bucket" "pipeline_artifacts" {
  bucket        = "ecom-cicd-artifacts-${var.account_id}"
  force_destroy = true 
}

# 2. CodeStar Connection to GitHub
resource "aws_codestarconnections_connection" "github" {
  name          = "github-connection"
  provider_type = "GitHub"
}

# 3. IAM Role for CodeBuild
resource "aws_iam_role" "codebuild_role" {
  name = "ecom-codebuild-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "codebuild.amazonaws.com" }
    }]
  })
}

# 4. CodeBuild Policy (ECR, Logs, S3)
resource "aws_iam_role_policy" "codebuild_policy" {
  role = aws_iam_role.codebuild_role.name
  name = "ecom-codebuild-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:GetObjectVersion", "s3:PutObject"]
        Resource = "${aws_s3_bucket.pipeline_artifacts.arn}/*"
      }
    ]
  })
}

# 5. CodeBuild Projects (One for each service)
resource "aws_codebuild_project" "build" {
  for_each      = toset(["customer", "products", "shopping"])
  name          = "${each.key}-build"
  service_role  = aws_iam_role.codebuild_role.arn

  artifacts { type = "CODEPIPELINE" }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/amazonlinux2-x86_64-standard:4.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = true # REQUIRED for Docker builds

    environment_variable {
      name  = "REPOSITORY_URI"
      value = "${var.account_id}.dkr.ecr.ap-south-1.amazonaws.com/${each.key}"
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "${each.key}/buildspec.yml"
  }
}