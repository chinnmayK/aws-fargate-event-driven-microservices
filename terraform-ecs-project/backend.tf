# ------------------------------------------------------------
# Terraform Backend Configuration (Remote State)
# ------------------------------------------------------------
# Configures Terraform to store its state file remotely in S3
# and use DynamoDB for state locking to prevent concurrent
# operations from corrupting the state.
terraform {
  backend "s3" {

    # S3 bucket where the Terraform state file is stored
    bucket = "ecom-microservice-app-bucket"

    # Path inside the bucket for the state file
    # Useful for separating environments (e.g., dev, prod)
    key = "prod/terraform.tfstate"

    # AWS region where the S3 bucket and DynamoDB table exist
    region = "ap-south-1"

    # DynamoDB table used for state locking and consistency
    dynamodb_table = "terraform-state-locking"

    # AWS CLI profile Terraform will use for authentication
    profile = "terraform-worker"
  }
}
