# ------------------------------------------------------------
# AWS Provider Configuration
# ------------------------------------------------------------
provider "aws" {
  region = "ap-south-1"
}

data "aws_caller_identity" "current" {}

# ------------------------------------------------------------
# 1. Identity Layer
# ------------------------------------------------------------
module "iam" {
  source = "./modules/iam"
}

# ------------------------------------------------------------
# 2. Networking Layer
# ------------------------------------------------------------
module "vpc" {
  source = "./modules/vpc"
}

# ------------------------------------------------------------
# 3. Application Load Balancer (ALB) Layer
# ------------------------------------------------------------
module "alb" {
  source         = "./modules/alb"
  vpc_id         = module.vpc.vpc_id
  public_subnets = module.vpc.public_subnets
  services       = ["customer", "products", "shopping"]
}

# ------------------------------------------------------------
# 4. Compute Layer (EC2 Auto Scaling with ALB Integration)
# ------------------------------------------------------------
module "compute" {
  source                = "./modules/compute"
  vpc_id                = module.vpc.vpc_id
  private_subnets       = module.vpc.private_subnets
  alb_sg_id             = module.alb.alb_sg_id
  instance_profile_name = module.iam.instance_profile_name

  # ✅ Simply pass the map output directly
  target_group_arns     = module.alb.target_group_arns
}

# ------------------------------------------------------------
# 5. Database Layer (DocumentDB / RDS)
# ------------------------------------------------------------
module "database" {
  source          = "./modules/database"
  vpc_id          = module.vpc.vpc_id
  private_subnets = module.vpc.private_subnets

  # FIXED: Now uses the EC2 security group from the compute module
  ecs_sg_id       = module.compute.ec2_sg_id 
}

# ------------------------------------------------------------
# 6. Messaging Layer (RabbitMQ / Amazon MQ)
# ------------------------------------------------------------
module "messaging" {
  source          = "./modules/messaging"
  vpc_id          = module.vpc.vpc_id
  private_subnets = module.vpc.private_subnets

  # FIXED: Now uses the EC2 security group from the compute module
  ecs_sg_id       = module.compute.ec2_sg_id
}

# -------------------------------
# 7. CI/CD Module
# -------------------------------
module "cicd" {
  source             = "./modules/cicd"
  account_id         = data.aws_caller_identity.current.account_id
  asg_names          = module.compute.asg_names
  alb_listener_arn   = module.alb.listener_arn
  target_group_names = module.alb.target_group_names
}

# ------------------------------------------------------------
# Outputs
# ------------------------------------------------------------
output "github_connection_arn" {
  value = module.cicd.connection_arn
}