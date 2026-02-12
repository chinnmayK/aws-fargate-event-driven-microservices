# ============================================================
# MESSAGING MODULE (Amazon MQ - RabbitMQ)
# ============================================================

# ------------------------------------------------------------
# Input Variables
# ------------------------------------------------------------

# ID of the VPC where the RabbitMQ broker will be deployed
variable "vpc_id" {}

# List of private subnet IDs used for broker placement
variable "private_subnets" {
  type = list(string)
}

# Security group ID of ECS tasks allowed to connect to RabbitMQ
variable "ecs_sg_id" {
  type = string
}

# ------------------------------------------------------------
# Amazon MQ Broker (RabbitMQ)
# ------------------------------------------------------------
# Creates a managed RabbitMQ broker for asynchronous
# communication between microservices.
resource "aws_mq_broker" "rabbitmq" {
  broker_name        = "microservices-rabbitmq"
  engine_type        = "RabbitMQ"
  engine_version     = "3.13"

  # Instance size for the broker (suitable for dev/small workloads)
  host_instance_type = "mq.t3.micro"

  # Broker is accessible only within the VPC
  publicly_accessible = false
  
  # Place the broker in a private subnet
  subnet_ids = [var.private_subnets[0]]

  # Security group restricting inbound access
  security_groups = [aws_security_group.mq_sg.id]

  # Automatically apply minor version upgrades
  auto_minor_version_upgrade = true 

  # RabbitMQ admin user credentials
  user {
    username = "adminuser"
    password = "SecurePassword123!" 
  }
}

# ------------------------------------------------------------
# Security Group for RabbitMQ
# ------------------------------------------------------------
# Allows secure (TLS) RabbitMQ traffic only from ECS tasks.
resource "aws_security_group" "mq_sg" {
  name   = "mq-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port       = 5671 # RabbitMQ TLS/SSL port
    to_port         = 5671
    protocol        = "tcp"

    # Restrict access to ECS task security group
    security_groups = [var.ecs_sg_id]
  }
}

