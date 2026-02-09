# ------------------------------------------------------------
# AWS Provider Configuration
# ------------------------------------------------------------
# Uses the AWS CLI profile created for Terraform operations
# and deploys all resources in the ap-south-1 (Mumbai) region.
provider "aws" {
  region  = "ap-south-1"
}

data "aws_caller_identity" "current" {}

# ------------------------------------------------------------
# VPC Module
# ------------------------------------------------------------
# Creates the core networking layer including:
# - VPC
# - Public subnets (for ALB)
# - Private subnets (for ECS, databases, messaging)
# - Routing, IGW, NAT Gateway
module "vpc" {
  source = "./modules/vpc"
}

# ------------------------------------------------------------
# ECR Module
# ------------------------------------------------------------
# Creates Amazon ECR repositories to store Docker images
# for all microservices.
module "ecr" {
  source = "./modules/ecr"
}

# ------------------------------------------------------------
# Application Load Balancer (ALB) Module
# ------------------------------------------------------------
# Provisions:
# - An internet-facing ALB
# - Listener rules
# - Target groups for each microservice
# Routes traffic to ECS services based on path or host rules.
module "alb" {
  source         = "./modules/alb"
  vpc_id         = module.vpc.vpc_id
  public_subnets = module.vpc.public_subnets

  # List of microservices exposed through the ALB
  services       = ["customer", "products", "shopping"]
}

# ------------------------------------------------------------
# Database Module
# ------------------------------------------------------------
# Creates database infrastructure (e.g., DocumentDB / RDS):
# - Deployed inside private subnets
# - Accessible only from ECS tasks via security groups
module "database" {
  source          = "./modules/database"
  vpc_id          = module.vpc.vpc_id
  private_subnets = module.vpc.private_subnets

  # Security group ID of ECS tasks allowed to access the database
  ecs_sg_id       = module.ecs.ecs_tasks_sg_id # We will create this output next
}

# ------------------------------------------------------------
# Messaging Module
# ------------------------------------------------------------
# Provisions messaging infrastructure (e.g., RabbitMQ / Amazon MQ):
# - Runs in private subnets
# - Used for asynchronous communication between services
module "messaging" {
  source          = "./modules/messaging"
  vpc_id          = module.vpc.vpc_id
  private_subnets = module.vpc.private_subnets

  # Allows ECS services to communicate with the messaging broker
  ecs_sg_id       = module.ecs.ecs_tasks_sg_id
}

# ------------------------------------------------------------
# ECS Module
# ------------------------------------------------------------
# Deploys containerized microservices using Amazon ECS:
# - ECS Cluster
# - Task Definitions
# - Services connected to ALB target groups
# - Networking and security configuration
module "ecs" {
  source            = "./modules/ecs"
  vpc_id            = module.vpc.vpc_id
  private_subnets   = module.vpc.private_subnets

  # ALB security group to allow inbound traffic from the load balancer
  alb_sg_id         = module.alb.alb_sg_id

  # Target groups created by the ALB module for each service
  target_group_arns = module.alb.target_group_arns
  
  # Backend service endpoints injected into ECS tasks as environment variables
  docdb_endpoint    = module.database.endpoint
  rabbitmq_endpoint = module.messaging.endpoint
}

module "cicd" {
  source     = "./modules/cicd"
  account_id = data.aws_caller_identity.current.account_id
}

# Output the ARN to your terminal
output "github_connection_arn" {
  value = module.cicd.connection_arn
}