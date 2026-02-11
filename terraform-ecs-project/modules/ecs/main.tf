# ============================================================
# ECS MODULE
# File: modules/ecs/main.tf
# ============================================================

# ------------------------------------------------------------
# ECS Cluster
# ------------------------------------------------------------
# Creates an ECS cluster to run all microservices using
# AWS Fargate (serverless containers).
resource "aws_ecs_cluster" "main" {
  name = "microservices-cluster"
}

# ------------------------------------------------------------
# IAM Roles and Policies (Permissions Layer)
# ------------------------------------------------------------

# ECS Task Execution Role
# Grants ECS permissions to:
# - Pull images from ECR
# - Write logs to CloudWatch
# - Read secrets from Secrets Manager
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecs_task_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

# Attach AWS-managed policy for ECR + CloudWatch Logs
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Custom IAM policy allowing ECS tasks to read secrets
# from AWS Secrets Manager
resource "aws_iam_role_policy" "secrets_policy" {
  name = "ecs-secrets-policy"
  role = aws_iam_role.ecs_task_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = [aws_secretsmanager_secret.app_secrets.arn]
    }]
  })
}

# Explicit CloudWatch Logs permissions (required for Fargate)
resource "aws_iam_role_policy" "ecs_logs_policy" {
  name = "ecs-logs-policy"
  role = aws_iam_role.ecs_task_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      Resource = "*"
    }]
  })
}

# ------------------------------------------------------------
# Networking (Security Groups)
# ------------------------------------------------------------

# Security Group for ECS Tasks
# - Allows inbound traffic only from the ALB
# - Restricts traffic to application ports
resource "aws_security_group" "ecs_tasks" {
  name        = "ecs-tasks-sg"
  description = "Allow inbound access from the ALB only"
  vpc_id      = var.vpc_id

  ingress {
    protocol        = "tcp"
    from_port       = 8001
    to_port         = 8003
    security_groups = [var.alb_sg_id]
  }

  # Allow all outbound traffic (required for AWS APIs)
  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ------------------------------------------------------------
# Secrets Management
# ------------------------------------------------------------

# Secrets Manager Secret
# Stores sensitive application configuration such as:
# - Database connection strings
# - Messaging broker credentials
resource "aws_secretsmanager_secret" "app_secrets" {
  name        = "microservices-secrets-v5"
  description = "Sensitive credentials for microservices"
}

# Secret Values (JSON)
# Injected into ECS containers securely at runtime
resource "aws_secretsmanager_secret_version" "app_secrets_val" {
  secret_id = aws_secretsmanager_secret.app_secrets.id

  secret_string = jsonencode({
    customer_mongodb_uri  = "mongodb://adminuser:SecurePassword123!@${var.docdb_endpoint}:27017/msytt_customer?tls=true&tlsAllowInvalidCertificates=true&retryWrites=false"
    products_mongodb_uri  = "mongodb://adminuser:SecurePassword123!@${var.docdb_endpoint}:27017/msytt_products?tls=true&tlsAllowInvalidCertificates=true&retryWrites=false"
    shopping_mongodb_uri  = "mongodb://adminuser:SecurePassword123!@${var.docdb_endpoint}:27017/msytt_shopping?tls=true&tlsAllowInvalidCertificates=true&retryWrites=false"

    rabbitmq_uri          = "amqps://adminuser:SecurePassword123!@${replace(var.rabbitmq_endpoint, "amqps://", "")}"

    app_secret            = "jg_youtube_tutorial"
  })
}

# ------------------------------------------------------------
# Logging
# ------------------------------------------------------------

# CloudWatch Log Group for ECS Tasks
# Centralizes logs for all microservices
resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = "/ecs/microservices"
  retention_in_days = 7
}

# ------------------------------------------------------------
# ECS Task Definitions
# ------------------------------------------------------------
# Defines container configuration for each microservice
resource "aws_ecs_task_definition" "service_task" {
  for_each                 = toset(["customer", "products", "shopping"])
  family                   = "${each.key}-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"

  # IAM role used by ECS agent
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = each.key
      image     = "202533520289.dkr.ecr.ap-south-1.amazonaws.com/${each.key}:latest"
      essential = true

      # Map container ports dynamically per service
      portMappings = [
        {
          containerPort = each.key == "customer" ? 8001 : (each.key == "products" ? 8002 : 8003)
          hostPort      = each.key == "customer" ? 8001 : (each.key == "products" ? 8002 : 8003)
          protocol      = "tcp"
        }
      ]

      # Plain environment variables
      environment = [
        { name = "PORT", value = tostring(each.key == "customer" ? 8001 : (each.key == "products" ? 8002 : 8003)) },
        { name = "EXCHANGE_NAME", value = "ONLINE_SHOPPING" }
      ]

      # Secrets injected securely from Secrets Manager
      secrets = [
        {
          name      = "MONGODB_URI"
          valueFrom = "${aws_secretsmanager_secret.app_secrets.arn}:${each.key}_mongodb_uri::"
        },
        {
          name      = "MSG_QUEUE_URL"
          valueFrom = "${aws_secretsmanager_secret.app_secrets.arn}:rabbitmq_uri::"
        },
        {
          name      = "APP_SECRET"
          valueFrom = "${aws_secretsmanager_secret.app_secrets.arn}:app_secret::"
        }
      ]

      # CloudWatch Logs configuration
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs.name
          "awslogs-region"        = "ap-south-1"
          "awslogs-stream-prefix" = each.key
        }
      }
    }
  ])
}

# ------------------------------------------------------------
# ECS Services
# ------------------------------------------------------------
# Runs and maintains desired number of task instances
# and integrates ECS with the Application Load Balancer.
resource "aws_ecs_service" "main" {
  for_each        = toset(["customer", "products", "shopping"])
  name            = "${each.key}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.service_task[each.key].arn
  desired_count   = 1
  launch_type     = "FARGATE"

  # Disable forced redeployments for customer
  force_new_deployment = each.key != "customer"

  # Disable timestamp trigger for customer
  triggers = each.key == "customer" ? {} : {
    redeployment = plantimestamp()
  }

  deployment_controller {
    type = each.key == "customer" ? "CODE_DEPLOY" : "ECS"
  }

  health_check_grace_period_seconds = 60

  network_configuration {
    security_groups  = [aws_security_group.ecs_tasks.id]
    subnets          = var.private_subnets
    assign_public_ip = true
  }

load_balancer {
    target_group_arn = var.target_group_arns[each.key]
    container_name   = each.key
    container_port   = each.key == "customer" ? 8001 : (
      each.key == "products" ? 8002 : 8003
    )
  }

  # Add this to prevent Terraform from fighting with CodeDeploy
  lifecycle {
    ignore_changes = [
      task_definition,
      load_balancer
    ]
  }
}

# ------------------------------------------------------------
# Outputs
# ------------------------------------------------------------
# Expose ECS task security group for use by other modules
output "ecs_tasks_sg_id" {
  value = aws_security_group.ecs_tasks.id
}

output "cluster_name" {
  value = aws_ecs_cluster.main.name
}