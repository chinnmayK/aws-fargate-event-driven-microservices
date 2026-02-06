# ------------------------------------------------------------
# AWS Provider Configuration
# ------------------------------------------------------------
# Defines the AWS region where all resources will be created.
provider "aws" {
  region = "ap-south-1"
}

# ------------------------------------------------------------
# 1. S3 Bucket for Terraform Remote State
# ------------------------------------------------------------
# This bucket stores the Terraform state file centrally,
# enabling collaboration and preventing state loss.
resource "aws_s3_bucket" "terraform_state" {
  bucket        = "ecom-microservice-app-bucket"
  force_destroy = true  # Allows Terraform to delete the bucket even if it contains objects
}

# ------------------------------------------------------------
# 2. Enable Versioning on the State Bucket
# ------------------------------------------------------------
# Keeps a full history of Terraform state changes, allowing
# rollback and recovery in case of accidental modifications.
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# ------------------------------------------------------------
# 3. DynamoDB Table for Terraform State Locking
# ------------------------------------------------------------
# Prevents concurrent Terraform executions from corrupting
# the state file by enabling state locking.
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "terraform-state-locking"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

# ------------------------------------------------------------
# 4. IAM User Dedicated for Terraform Operations
# ------------------------------------------------------------
# This user is intended to be used by Terraform for managing
# AWS infrastructure programmatically.
resource "aws_iam_user" "tf_user" {
  name = "terraform-worker"
}

# ------------------------------------------------------------
# 5. Attach PowerUserAccess Policy
# ------------------------------------------------------------
# Grants broad permissions to create and manage AWS resources
# except for IAM-related administrative actions.
resource "aws_iam_user_policy_attachment" "tf_user_admin" {
  user       = aws_iam_user.tf_user.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

# ------------------------------------------------------------
# 6. Create Access Keys for the Terraform IAM User
# ------------------------------------------------------------
# These credentials are used by Terraform to authenticate
# with AWS APIs.
resource "aws_iam_access_key" "tf_user_key" {
  user = aws_iam_user.tf_user.name
}

# ------------------------------------------------------------
# 7. Output Access Credentials (Shown Only Once)
# ------------------------------------------------------------
# Access Key ID is safe to display.
output "access_key_id" {
  value = aws_iam_access_key.tf_user_key.id
}

# Secret Access Key is marked as sensitive and will not
# be displayed in plain text in Terraform logs.
output "secret_access_key" {
  value     = aws_iam_access_key.tf_user_key.secret
  sensitive = true
}

# ------------------------------------------------------------
# 8. Attach IAMFullAccess Policy
# ------------------------------------------------------------
# Allows Terraform to manage IAM resources such as roles,
# policies, and users when required.
# NOTE: This is powerful and should be restricted in
# production environments.
resource "aws_iam_user_policy_attachment" "tf_user_iam" {
  user       = aws_iam_user.tf_user.name
  policy_arn = "arn:aws:iam::aws:policy/IAMFullAccess"
}
