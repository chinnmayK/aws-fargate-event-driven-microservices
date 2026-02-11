# ============================================================
# ALB MODULE
# File: modules/alb/main.tf
# ============================================================

# 1. Application Load Balancer
resource "aws_lb" "main" {
  name               = "microservices-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = var.public_subnets

  tags = { Name = "microservices-alb" }
}

# 2. Security Group for ALB
resource "aws_security_group" "alb_sg" {
  name   = "alb-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

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
# Local variable to map service names to their specific ports
locals {
  service_ports = {
    customer = 8001
    products = 8002
    shopping = 8003
  }
}

resource "aws_lb_target_group" "tg" {
  for_each    = toset(["customer", "products", "shopping"])
  name_prefix = substr(each.key, 0, 6)
  port        = local.service_ports[each.key] # Port matches Node.js app port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance" # CRITICAL CHANGE: Switched from "ip" to "instance"
  lifecycle {
    create_before_destroy = true
  }

  health_check {
    path                = "/${each.key}/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_target_group" "customer_green" {
  name_prefix = "cust-g"
  port        = 8001 # Port matches Customer Service port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance" # CRITICAL CHANGE: Switched from "ip" to "instance"
  lifecycle {
    create_before_destroy = true
  }

  health_check {
    path                = "/customer/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# 4. ALB Listener (HTTP :80)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "404: Not Found"
      status_code  = "404"
    }
  }
}

# 5. Listener Rules (Path-Based Routing)
resource "aws_lb_listener_rule" "rules" {
  for_each     = aws_lb_target_group.tg
  listener_arn = aws_lb_listener.http.arn

  action {
    type             = "forward"
    target_group_arn = each.value.arn
  }

  condition {
    path_pattern {
      values = ["/${each.key}", "/${each.key}/*"]
    }
  }

  lifecycle {
    ignore_changes = [action]
  }
}

# ------------------------------------------------------------
# Outputs
# ------------------------------------------------------------
output "alb_dns_name" {
  value = aws_lb.main.dns_name
}

output "target_group_arns" {
  value = { for k, v in aws_lb_target_group.tg : k => v.arn }
}

output "target_group_names" {
  value = { for k, v in aws_lb_target_group.tg : k => v.name }
}

output "alb_sg_id" {
  value = aws_security_group.alb_sg.id
}

output "listener_arn" {
  value = aws_lb_listener.http.arn
}