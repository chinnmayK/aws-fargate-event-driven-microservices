variable "vpc_id" {
  type        = string
  description = "The ID of the VPC where EC2 instances will reside"
}

variable "private_subnets" {
  type        = list(string)
  description = "List of private subnet IDs for the Auto Scaling Group"
}

variable "alb_sg_id" {
  type        = string
  description = "The Security Group ID of the Load Balancer to allow traffic"
}

variable "instance_profile_name" {
  type        = string
  description = "The IAM Instance Profile name with S3 and CodeDeploy permissions"
}

variable "target_group_arns" {
  description = "Map of target group ARNs for the microservices"
  type        = map(string)
}