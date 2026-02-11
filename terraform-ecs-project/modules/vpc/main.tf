# ============================================================
# VPC MODULE
# File: modules/vpc/main.tf
# ============================================================

# ------------------------------------------------------------
# 1. VPC Configuration
# ------------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true 
  tags                 = { Name = "microservices-vpc" }
}

# ------------------------------------------------------------
# 2. Gateways & Availability Zones
# ------------------------------------------------------------
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
}

data "aws_availability_zones" "available" {}

# ------------------------------------------------------------
# 3. Subnets
# ------------------------------------------------------------

# Public Subnets (For ALB)
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.${count.index}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  tags                    = { Name = "public-subnet-${count.index}" }
}

# Private Subnets (For EC2 Instances)
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 10}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags              = { Name = "private-subnet-${count.index}" }
}

# ------------------------------------------------------------
# 4. Routing Logic
# ------------------------------------------------------------

# Public Routing
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = { Name = "public-rt" }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private Routing (Critical for S3 Gateway Endpoint)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "private-rt" }
}

resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# ------------------------------------------------------------
# 5. VPC Endpoints (The "No NAT" Connectivity Layer)
# ------------------------------------------------------------

# Unified Security Group for Interface Endpoints
resource "aws_security_group" "vpc_endpoints" {
  name   = "vpc-endpoints-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block] 
  }
}

# S3 Gateway Endpoint
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.ap-south-1.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]
}

# Interface Endpoints for ECR, Secrets, Logs, and SSM (Connect Button)
resource "aws_vpc_endpoint" "interface_endpoints" {
  for_each = toset([
    "ecr.api",
    "ecr.dkr",
    "secretsmanager",
    "logs",
    "ssm",
    "ssmmessages",
    "ec2messages",
    "codedeploy",
    "codedeploy-commands-secure"
  ])

  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.ap-south-1.${each.value}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
}

# ------------------------------------------------------------
# 6. Outputs
# ------------------------------------------------------------
output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnets" {
  value = aws_subnet.public[*].id
}

output "private_subnets" {
  value = aws_subnet.private[*].id
}