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
  source          = "./modules/iam"
  # ✅ FIXED: Passing the secret ARN to the IAM module
  app_secrets_arn = aws_secretsmanager_secret.app_secrets.arn
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
  target_group_arns     = module.alb.target_group_arns
}

# ------------------------------------------------------------
# 5. Database Layer (DocumentDB / RDS)
# ------------------------------------------------------------
module "database" {
  source          = "./modules/database"
  vpc_id          = module.vpc.vpc_id
  private_subnets = module.vpc.private_subnets
  ecs_sg_id       = module.compute.ec2_sg_id 
}

# ------------------------------------------------------------
# 6. Messaging Layer (RabbitMQ / Amazon MQ)
# ------------------------------------------------------------
module "messaging" {
  source          = "./modules/messaging"
  vpc_id          = module.vpc.vpc_id
  private_subnets = module.vpc.private_subnets
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
# 8. Secrets Management (Professional Fix)
# ------------------------------------------------------------

# 1. Create the Secret Container in root
resource "aws_secretsmanager_secret" "app_secrets" {
  name        = "microservices-secrets-v6"
  description = "Production secrets for all microservices"
}

# 2. Store JSON values (Dynamic endpoints from modules)
resource "aws_secretsmanager_secret_version" "app_secrets_val" {
  secret_id     = aws_secretsmanager_secret.app_secrets.id
  secret_string = jsonencode({
    # Common variables
    NODE_ENV      = "prod"
    EXCHANGE_NAME = "ONLINE_SHOPPING"
    APP_SECRET    = "your_secure_jwt_secret"

    # Service-specific Database URIs
    CUSTOMER_DB_URI = "mongodb://adminuser:SecurePassword123!@${module.database.db_endpoint}:27017/customer?tls=true&replicaSet=rs0&retryWrites=false"
    PRODUCTS_DB_URI = "mongodb://adminuser:SecurePassword123!@${module.database.db_endpoint}:27017/products?tls=true&replicaSet=rs0&retryWrites=false"
    SHOPPING_DB_URI = "mongodb://adminuser:SecurePassword123!@${module.database.db_endpoint}:27017/shopping?tls=true&replicaSet=rs0&retryWrites=false"

    # Shared Messaging URL
    MSG_QUEUE_URL   = "amqps://adminuser:SecurePassword123!@${module.messaging.broker_endpoint}:5671"
  })
}