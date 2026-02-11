# ============================================================
# ALB MODULE VARIABLES
# File: modules/alb/variables.tf
# ============================================================

# ------------------------------------------------------------
# VPC ID
# ------------------------------------------------------------
variable "vpc_id" {
  description = "The ID of the VPC where the ALB will be created"
  type        = string
}

# ------------------------------------------------------------
# Public Subnets
# ------------------------------------------------------------
variable "public_subnets" {
  description = "List of public subnet IDs for ALB deployment"
  type        = list(string)
}

# ------------------------------------------------------------
# Services
# ------------------------------------------------------------
# We keep this for the routing logic, but the actual port 
# mapping is handled in the main.tf locals.
variable "services" {
  description = "Set of microservice names for path-based routing"
  type        = set(string)
  default     = ["customer", "products", "shopping"]
}

# ------------------------------------------------------------
# Optional: Service Port Mapping (Alternative to Locals)
# ------------------------------------------------------------
# If you prefer to pass ports from the root main.tf instead 
# of hardcoding them in main.tf's locals, you can use this:
variable "service_ports" {
  description = "Map of service names to their application ports"
  type        = map(number)
  default = {
    customer = 8001
    products = 8002
    shopping = 8003
  }
}
