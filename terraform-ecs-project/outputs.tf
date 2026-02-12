# ------------------------------------------------------------
# CI/CD Outputs
# ------------------------------------------------------------
output "github_connection_arn" {
  description = "The ARN of the GitHub connection for CodePipeline"
  value       = module.cicd.connection_arn
}

# ------------------------------------------------------------
# Database Outputs
# ------------------------------------------------------------
output "mongodb_endpoint" {
  description = "The DocumentDB cluster endpoint"
  value       = module.database.db_endpoint
}

# ------------------------------------------------------------
# Messaging Outputs
# ------------------------------------------------------------
output "amqp_endpoint" {
  description = "The RabbitMQ / Amazon MQ endpoint"
  value       = module.messaging.broker_endpoint
}

# ------------------------------------------------------------
# Networking / ALB Outputs
# ------------------------------------------------------------
output "alb_dns_name" {
  description = "The public URL of your microservices"
  value       = module.alb.alb_dns_name
}
