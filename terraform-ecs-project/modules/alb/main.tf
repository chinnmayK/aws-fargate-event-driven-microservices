# ============================================================
# ALB MODULE
# File: modules/alb/main.tf
# ============================================================

# ------------------------------------------------------------
# 1. Application Load Balancer
# ------------------------------------------------------------
# Creates an internet-facing Application Load Balancer that
# routes HTTP traffic to backend ECS services.
resource "aws_lb" "main" {
  name               = "microservices-alb"
  internal           = false
  load_balancer_type = "application"

  # Security group controlling inbound/outbound traffic
  security_groups    = [aws_security_group.alb_sg.id]

  # Public subnets where the ALB will be deployed
  subnets            = var.public_subnets

  tags = { Name = "microservices-alb" }
}

# ------------------------------------------------------------
# 2. Security Group for ALB
# ------------------------------------------------------------
# Allows inbound HTTP traffic from the internet and
# unrestricted outbound traffic to backend services.
resource "aws_security_group" "alb_sg" {
  name   = "alb-sg"
  vpc_id = var.vpc_id

  # Allow HTTP traffic from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ------------------------------------------------------------
# 3. Target Groups (One per Microservice)
# ------------------------------------------------------------
# Creates a separate target group for each service.
# These target groups will be attached to ECS services
# running on AWS Fargate.
resource "aws_lb_target_group" "tg" {
  for_each    = toset(["customer", "products", "shopping"])
  name        = "${each.key}-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip" # Required for ECS Fargate tasks

  # Health check configuration for service containers
  health_check {
    path                = "/health" # Common health endpoint across services
    port                = "traffic-port"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# ------------------------------------------------------------
# 4. ALB Listener (HTTP :80)
# ------------------------------------------------------------
# Listens for incoming HTTP requests and forwards them
# to the appropriate target group based on routing rules.
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  # Default response when no routing rules match
  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "404: Not Found"
      status_code  = "404"
    }
  }
}

# ------------------------------------------------------------
# 5. Listener Rules (Path-Based Routing)
# ------------------------------------------------------------
# Routes traffic to target groups based on URL path.
# This replaces traditional reverse-proxy logic (e.g., Nginx).
resource "aws_lb_listener_rule" "rules" {
  for_each     = aws_lb_target_group.tg
  listener_arn = aws_lb_listener.http.arn

  action {
    type             = "forward"
    target_group_arn = each.value.arn
  }

  condition {
    path_pattern {
      values = ["/${each.key}*"]
    }
  }
}

# ------------------------------------------------------------
# 6. Service-Specific Listener Rules
# ------------------------------------------------------------
# Explicit routing rules per service to handle:
# - /service
# - /service/*
# Useful for testing and cleaner URL matching.
resource "aws_lb_listener_rule" "service_rule" {
  for_each     = var.services
  listener_arn = aws_lb_listener.http.arn

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg[each.key].arn
  }

  condition {
    path_pattern {
      values = ["/${each.key}/*", "/${each.key}"]
    }
  }
}

# ------------------------------------------------------------
# Outputs
# ------------------------------------------------------------
# Expose ALB details for use by ECS and root module
output "alb_dns_name" {
  value = aws_lb.main.dns_name
}

output "target_group_arns" {
  value = { for k, v in aws_lb_target_group.tg : k => v.arn }
}

output "alb_sg_id" {
  value = aws_security_group.alb_sg.id
}
