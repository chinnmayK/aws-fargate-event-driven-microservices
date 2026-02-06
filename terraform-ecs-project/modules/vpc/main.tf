# ============================================================
# VPC MODULE
# File: modules/vpc/main.tf
# ============================================================

# ------------------------------------------------------------
# VPC
# ------------------------------------------------------------
# Creates the main VPC for the microservices architecture.
# DNS support is enabled to allow:
# - Private DNS for VPC Interface Endpoints
# - Service discovery inside the VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true # Required for Private DNS on Interface Endpoints
  tags                 = { Name = "microservices-vpc" }
}

# ------------------------------------------------------------
# Internet Gateway
# ------------------------------------------------------------
# Enables internet access for public subnets (used by ALB).
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
}

# ------------------------------------------------------------
# Availability Zones
# ------------------------------------------------------------
# Fetches available AZs dynamically for high availability.
data "aws_availability_zones" "available" {}

# ------------------------------------------------------------
# Subnets
# ------------------------------------------------------------

# Public Subnets
# - Spread across multiple AZs
# - Used for internet-facing resources (ALB)
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.${count.index}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  tags                    = { Name = "public-subnet-${count.index}" }
}

# Private Subnets
# - Spread across multiple AZs
# - Used for ECS tasks, databases, and messaging services
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 10}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags              = { Name = "private-subnet-${count.index}" }
}

# ------------------------------------------------------------
# Routing
# ------------------------------------------------------------

# Public Route Table
# - Routes internet-bound traffic via the Internet Gateway
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = { Name = "public-rt" }
}

# Associate Public Subnets with Public Route Table
resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private Route Table
# - Used by private subnets
# - Required for S3 Gateway Endpoint routing
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "private-rt" }
}

# Associate Private Subnets with Private Route Table
resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# ------------------------------------------------------------
# VPC Endpoints (Private AWS Service Access)
# ------------------------------------------------------------
# Enables private, secure access to AWS services without
# requiring internet or NAT Gateway access.

# Security Group for Interface Endpoints
# Allows HTTPS traffic only from within the VPC
resource "aws_security_group" "vpc_endpoints" {
  name   = "vpc-endpoints-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block] # Restrict access to VPC CIDR
  }
}

# ECR API Endpoint
# Used by ECS to authenticate with Amazon ECR
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.ap-south-1.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
}

# ECR Docker Endpoint
# Used by ECS to pull container images
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.ap-south-1.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
}

# Secrets Manager Endpoint
# Allows ECS tasks to retrieve secrets securely
resource "aws_vpc_endpoint" "secrets" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.ap-south-1.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
}

# S3 Gateway Endpoint
# Allows private subnets to access S3 without internet/NAT
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.ap-south-1.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]
}

# CloudWatch Logs Endpoint
# Enables ECS tasks to send logs privately to CloudWatch
resource "aws_vpc_endpoint" "logs" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.ap-south-1.logs" # Mumbai region
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
}

# ------------------------------------------------------------
# Outputs
# ------------------------------------------------------------
# Expose VPC and subnet IDs for use by other modules
output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnets" {
  value = aws_subnet.public[*].id
}

output "private_subnets" {
  value = aws_subnet.private[*].id
}
