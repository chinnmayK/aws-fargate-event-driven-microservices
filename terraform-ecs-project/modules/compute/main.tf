############################################
# 1. Security Group for EC2 Instances
############################################

resource "aws_security_group" "ec2_sg" {
  name   = "ecom-ec2-sg"
  vpc_id = var.vpc_id

  # Inbound: ALB → App (8001–8003)
  ingress {
    from_port       = 8001
    to_port         = 8003
    protocol        = "tcp"
    security_groups = [var.alb_sg_id]
  }

  # Inbound: SSH (Restrict in production!)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound: Allow all (for NAT internet access)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ecom-ec2-sg"
  }
}

############################################
# 2. Launch Template (Clean Ubuntu 24.04)
############################################

resource "aws_launch_template" "app" {
  name_prefix             = "ecom-app-final-"
  image_id                = "ami-019715e0d74f695be" # Ubuntu 24.04 LTS (ap-south-1)
  instance_type           = "t3.micro"
  update_default_version  = true   # ✅ Ensures ASG tracks newest version

  iam_instance_profile {
    name = var.instance_profile_name
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.ec2_sg.id]
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -ex

    # ✅ Wait for network to be fully ready (Fix race condition)
    sleep 10

    # Update system packages (works via NAT)
    apt-get update -y
    apt-get upgrade -y

    # Install dependencies
    apt-get install -y ruby-full wget curl

    # Install CodeDeploy Agent
    cd /home/ubuntu
    wget https://aws-codedeploy-ap-south-1.s3.ap-south-1.amazonaws.com/latest/install
    chmod +x ./install
    ./install auto

    # Enable & start CodeDeploy
    systemctl enable codedeploy-agent
    systemctl restart codedeploy-agent
  EOF
  )

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "ecom-app-instance"
    }
  }
}

############################################
# 3. Auto Scaling Groups (Updated)
############################################

resource "aws_autoscaling_group" "app" {
  for_each            = toset(["customer", "products", "shopping"])
  name                = "${each.key}-asg"
  vpc_zone_identifier = var.private_subnets
  desired_capacity    = 1
  min_size            = 1
  max_size            = 2

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest" # $Latest works better when update_default_version is true
  }

  # ✅ THIS IS THE CRITICAL MISSING LINK
  # Connects the ASG to the correct Target Group so instances register automatically
  target_group_arns = [var.target_group_arns[each.key]]

  tag {
    key                 = "Name"
    value               = "${each.key}-service"
    propagate_at_launch = true
  }

  tag {
    key                 = "Service"
    value               = each.key
    propagate_at_launch = true
  }
}
