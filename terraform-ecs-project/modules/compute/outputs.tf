output "ec2_sg_id" {
  value = aws_security_group.ec2_sg.id
}

output "asg_names" {
  value = {
    for k, v in aws_autoscaling_group.app : k => v.name
  }
}

output "launch_template_id" {
  value = aws_launch_template.app.id
}