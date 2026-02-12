# ------------------------------------------------------------
# 1. Target Group ARNs (Map for Compute / CI-CD modules)
# ------------------------------------------------------------
output "target_group_arns" {
  description = "Map of service names to target group ARNs"
  value       = { for k, v in aws_lb_target_group.tg : k => v.arn }
}

# ------------------------------------------------------------
# 2. Target Group Names (Optional)
# ------------------------------------------------------------
output "target_group_names" {
  description = "Map of service names to target group names"
  value       = { for k, v in aws_lb_target_group.tg : k => v.name }
}

# ------------------------------------------------------------
# 3. Individual ARNs (Optional - only if really needed)
# ------------------------------------------------------------
output "customer_target_group_arn" {
  value = aws_lb_target_group.tg["customer"].arn
}

output "products_target_group_arn" {
  value = aws_lb_target_group.tg["products"].arn
}

output "shopping_target_group_arn" {
  value = aws_lb_target_group.tg["shopping"].arn
}

# ------------------------------------------------------------
# 4. ALB General Info
# ------------------------------------------------------------
output "alb_dns_name" {
  description = "The public DNS name of the Load Balancer"
  value       = aws_lb.main.dns_name
}

output "alb_sg_id" {
  description = "Security Group ID of the ALB"
  value       = aws_security_group.alb_sg.id
}

output "listener_arn" {
  description = "ARN of the HTTP listener"
  value       = aws_lb_listener.http.arn
}
