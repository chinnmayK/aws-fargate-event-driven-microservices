# --- 1. EC2 Instance Role & Profile ---

resource "aws_iam_role" "ec2_instance_role" {
  name = "ecom-ec2-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

# Attach policy so EC2 can pull from S3 and talk to CodeDeploy
resource "aws_iam_role_policy_attachment" "ec2_s3_readonly" {
  role       = aws_iam_role.ec2_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "ec2_codedeploy_agent" {
  role       = aws_iam_role.ec2_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforAWSCodeDeploy"
}

# Required for EC2 instances to appear in the console
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ecom-ec2-instance-profile"
  role = aws_iam_role.ec2_instance_role.name
}


# --- 2. CodeDeploy Service Role ---

resource "aws_iam_role" "codedeploy_service_role" {
  name = "ecom-codedeploy-service-role-ec2"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "codedeploy.amazonaws.com" }
    }]
  })
}

# AWS Managed policy specifically for EC2-based CodeDeploy
resource "aws_iam_role_policy_attachment" "codedeploy_service" {
  role       = aws_iam_role.codedeploy_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
}

output "instance_profile_name" {
  value = aws_iam_instance_profile.ec2_profile.name
}

output "codedeploy_role_arn" {
  value = aws_iam_role.codedeploy_service_role.arn
}