variable "account_id" {
  type        = string
  description = "AWS Account ID"
}

variable "asg_names" {
  type        = map(string)
  description = "Map of service names to their respective Auto Scaling Groups"
}

variable "alb_listener_arn" {
  type        = string
  description = "The ARN of the ALB Listener"
}


variable "target_group_names" {
  type        = map(string)
  description = "Map of service names to their ALB Target Group names"
}