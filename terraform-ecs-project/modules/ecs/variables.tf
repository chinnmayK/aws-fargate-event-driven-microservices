variable "vpc_id" {
  description = "The VPC ID where the ECS tasks will run"
  type        = string
}

variable "private_subnets" {
  description = "List of private subnets for ECS tasks"
  type        = list(string)
}

variable "alb_sg_id" {
  description = "Security group ID of the ALB to allow inbound traffic"
  type        = string
}

variable "target_group_arns" {
  description = "Map of target group ARNs for the services"
  type        = map(string)
}

variable "docdb_endpoint" {
  description = "DocumentDB cluster endpoint"
  type        = string
}

variable "rabbitmq_endpoint" {
  description = "Amazon MQ (RabbitMQ) endpoint"
  type        = string
}