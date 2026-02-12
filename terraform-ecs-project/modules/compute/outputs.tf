output "ec2_sg_id" {
  description = "ID of the EC2 security group"
  value       = aws_security_group.ec2_sg.id
}

output "asg_names" {
  description = "Map of service names to ASG names"
  value       = { for k, v in aws_autoscaling_group.app : k => v.name }
}

output "launch_template_id" {
  description = "ID of the launch template"
  value       = aws_launch_template.app.id
}
