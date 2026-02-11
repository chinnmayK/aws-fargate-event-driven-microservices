output "ec2_sg_id" {
  value = aws_security_group.ec2_sg.id
}

output "asg_names" {
  value = {
    customer = aws_autoscaling_group.app["customer"].name
    products = aws_autoscaling_group.app["products"].name
    shopping = aws_autoscaling_group.app["shopping"].name
  }
}