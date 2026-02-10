variable "account_id" {
  description = "AWS Account ID for unique naming"
  type        = string
}
variable "cluster_name" { type = string }
variable "service_name" { type = string }
variable "alb_listener_arn" { type = string }
variable "blue_target_group_name" { type = string }
variable "green_target_group_name" { type = string }