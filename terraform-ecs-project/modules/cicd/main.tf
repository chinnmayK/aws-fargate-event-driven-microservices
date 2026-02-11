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
    privileged_mode = true

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

# 6. IAM Role for CodePipeline
resource "aws_iam_role" "pipeline_role" {
  name = "ecom-pipeline-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "codepipeline.amazonaws.com" }
    }]
  })
}

# 7. Pipeline Policy (ECS removed, EC2 CodeDeploy retained)
resource "aws_iam_role_policy" "pipeline_policy" {
  role = aws_iam_role.pipeline_role.name
  name = "ecom-pipeline-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:GetBucketVersioning",
          "s3:PutObjectAcl",
          "s3:PutObject"
        ]
        Resource = [
          aws_s3_bucket.pipeline_artifacts.arn,
          "${aws_s3_bucket.pipeline_artifacts.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = ["codestar-connections:UseConnection"]
        Resource = aws_codestarconnections_connection.github.arn
      },
      {
        Effect = "Allow"
        Action = ["codebuild:BatchGetBuilds", "codebuild:StartBuild"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "codedeploy:CreateDeployment",
          "codedeploy:GetDeployment",
          "codedeploy:GetDeploymentConfig",
          "codedeploy:GetApplication",
          "codedeploy:GetApplicationRevision",
          "codedeploy:RegisterApplicationRevision"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = "iam:PassRole"
        Resource = aws_iam_role.codedeploy_role.arn
      }
    ]
  })
}

# IAM Role for CodeDeploy
resource "aws_iam_role" "codedeploy_role" {
  name = "ecom-codedeploy-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "codedeploy.amazonaws.com" }
    }]
  })
}

# Updated to EC2 policy
resource "aws_iam_role_policy_attachment" "codedeploy_ec2" {
  role       = aws_iam_role.codedeploy_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
}

# -------------------------------
# CodeDeploy Applications (Dynamic)
# -------------------------------
resource "aws_codedeploy_app" "services" {
  for_each         = toset(["customer", "products", "shopping"])
  compute_platform = "Server"
  name             = "${each.key}-service-deploy"
}

# -------------------------------
# CodeDeploy Deployment Groups (Dynamic)
# -------------------------------
resource "aws_codedeploy_deployment_group" "services" {
  for_each               = toset(["customer", "products", "shopping"])
  app_name               = aws_codedeploy_app.services[each.key].name
  deployment_group_name  = "${each.key}-deployment-group"
  deployment_config_name = "CodeDeployDefault.AllAtOnce"
  service_role_arn       = aws_iam_role.codedeploy_role.arn

  autoscaling_groups = [var.asg_names[each.key]]

deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL" # This links to the ALB
    deployment_type   = "BLUE_GREEN"           # This creates new instances
  }

  blue_green_deployment_config {
    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }
    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 5
    }
  }

load_balancer_info {
    target_group_info {
      # Use the variable we just created
      name = var.target_group_names[each.key] 
    }
  }
}

# -------------------------------
# 8. The Pipelines (One for each service)
# -------------------------------

resource "aws_codepipeline" "service_pipeline" {
  for_each = toset(["customer", "products", "shopping"])

  name     = "${each.key}-pipeline"
  role_arn = aws_iam_role.pipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.pipeline_artifacts.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        ConnectionArn    = aws_codestarconnections_connection.github.arn
        FullRepositoryId = "chinnmayK/aws-fargate-event-driven-microservices"
        BranchName       = "main"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]

      configuration = {
        ProjectName = aws_codebuild_project.build[each.key].name
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeploy"
      version         = "1"
      input_artifacts = ["build_output"]

      configuration = {
        ApplicationName     = aws_codedeploy_app.services[each.key].name
        DeploymentGroupName = aws_codedeploy_deployment_group.services[each.key].deployment_group_name
      }
    }
  }
}
