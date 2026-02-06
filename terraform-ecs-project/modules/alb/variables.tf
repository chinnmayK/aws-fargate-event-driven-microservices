# ============================================================
# ALB MODULE VARIABLES
# File: modules/alb/variables.tf
# ============================================================

# ------------------------------------------------------------
# VPC ID
# ------------------------------------------------------------
# The ID of the VPC where the Application Load Balancer
# and its security group will be created.
variable "vpc_id" {
  type = string
}

# ------------------------------------------------------------
# Public Subnets
# ------------------------------------------------------------
# List of public subnet IDs where the ALB will be deployed.
# These subnets must have internet access via an IGW.
variable "public_subnets" {
  type = list(string)
}

# ------------------------------------------------------------
# Services
# ------------------------------------------------------------
# Set of microservice names exposed through the ALB.
# Each service will have:
# - Its own target group
# - Path-based routing rules (e.g., /service, /service/*)
variable "services" {
  type    = set(string)
  default = ["customer", "products", "shopping"]
}
