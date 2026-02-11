# 1. Security Group for EC2 Instances
resource "aws_security_group" "ec2_sg" {
  name        = "ecom-ec2-sg"
  vpc_id      = var.vpc_id

  # Allow HTTP from ALB only
  ingress {
    from_port       = 8001
    to_port         = 8003
    protocol        = "tcp"
    security_groups = [var.alb_sg_id]
  }

  # Allow SSH for debugging (Optional - change CIDR to your IP)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 2. Launch Template (The Blueprint)
resource "aws_launch_template" "app" {
  name_prefix   = "ecom-app-"
  image_id      = "ami-007020fd9c84e18c7" # Amazon Linux 2 (Mumbai)
  instance_type = "t3.micro"

  iam_instance_profile {
    name = var.instance_profile_name
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.ec2_sg.id]
  }

  # THIS SCRIPT INSTALLS THE CODEDEPLOY AGENT ON BOOT
  user_data = base64encode(<<-EOF
              #!/bin/bash
              sudo yum update -y
              sudo yum install -y ruby wget
              cd /home/ec2-user
              wget https://aws-codedeploy-ap-south-1.s3.ap-south-1.amazonaws.com/latest/install
              chmod +x ./install
              sudo ./install auto
              sudo systemctl start codedeploy-agent
              EOF
  )
}

# 3. Auto Scaling Group (The Fleet Manager)
resource "aws_autoscaling_group" "app" {
  for_each            = toset(["customer", "products", "shopping"])
  name                = "${each.key}-asg"
  vpc_zone_identifier = var.private_subnets
  desired_capacity    = 1
  max_size            = 2
  min_size            = 1

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${each.key}-service"
    propagate_at_launch = true
  }
}