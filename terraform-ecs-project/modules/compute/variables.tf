variable "vpc_id" {
  type        = string
  description = "The ID of the VPC"
}

variable "private_subnets" {
  type        = list(string)
  description = "The list of private subnets for the ASG"
}

variable "alb_sg_id" {
  type        = string
  description = "The security group ID of the ALB"
}

variable "instance_profile_name" {
  type        = string
  description = "The IAM instance profile for EC2"
}