# ============================================================
# DATABASE MODULE (Amazon DocumentDB)
# ============================================================

# ------------------------------------------------------------
# Input Variables
# ------------------------------------------------------------

# ID of the VPC where DocumentDB will be deployed
variable "vpc_id" {}

# List of private subnet IDs used for the DocumentDB subnet group
variable "private_subnets" {
  type = list(string)
}

# Security group ID of ECS tasks allowed to access DocumentDB
variable "ecs_sg_id" {
  type = string
}

# ------------------------------------------------------------
# DocumentDB Cluster
# ------------------------------------------------------------
# Creates an Amazon DocumentDB cluster for storing application data.
# The cluster is deployed in private subnets and accessible only
# from ECS services via security groups.
resource "aws_docdb_cluster" "docdb" {
  cluster_identifier     = "microservices-cluster"
  engine                 = "docdb"

  # Master credentials for the DocumentDB cluster
  master_username        = "adminuser"
  master_password        = "SecurePassword123!"

  # Disable final snapshot for easier teardown in non-production
  skip_final_snapshot    = true

  # Subnet group defining where the cluster can be placed
  db_subnet_group_name   = aws_docdb_subnet_group.main.name

  # Restrict network access using security groups
  vpc_security_group_ids = [aws_security_group.docdb_sg.id]
}

# ------------------------------------------------------------
# DocumentDB Cluster Instance
# ------------------------------------------------------------
# Provisions a single instance within the DocumentDB cluster.
resource "aws_docdb_cluster_instance" "cluster_instances" {
  identifier         = "docdb-instance"
  cluster_identifier = aws_docdb_cluster.docdb.id
  instance_class     = "db.t3.medium"
}

# ------------------------------------------------------------
# DocumentDB Subnet Group
# ------------------------------------------------------------
# Ensures DocumentDB instances are launched only
# in the provided private subnets.
resource "aws_docdb_subnet_group" "main" {
  name       = "docdb-subnet-group"
  subnet_ids = var.private_subnets
}

# ------------------------------------------------------------
# Security Group for DocumentDB
# ------------------------------------------------------------
# Allows inbound MongoDB traffic only from ECS tasks.
resource "aws_security_group" "docdb_sg" {
  name   = "docdb-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port       = 27017
    to_port         = 27017
    protocol        = "tcp"

    # Only ECS task security group is allowed to access the database
    security_groups = [var.ecs_sg_id]
  }
}

# ------------------------------------------------------------
# Outputs
# ------------------------------------------------------------
# Expose the DocumentDB endpoint for ECS services to connect to
output "endpoint" {
  value = aws_docdb_cluster.docdb.endpoint
}
