############################################
# 1. Security Group for EC2 Instances
############################################
resource "aws_security_group" "ec2_sg" {
  name   = "ecom-ec2-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port       = 8001
    to_port         = 8003
    protocol        = "tcp"
    security_groups = [var.alb_sg_id]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

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

  tags = { Name = "ecom-ec2-sg" }
}

############################################
# 2. Launch Template
############################################
resource "aws_launch_template" "app" {
  name_prefix   = "ecom-app-"
  image_id      = "ami-0317b0f0a0144b137" # Amazon Linux 2023
  instance_type = "t3.micro"

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

    # 1. Install Ruby
    dnf install -y ruby

    # 2. Download and Install CodeDeploy Agent
    aws s3 cp s3://aws-codedeploy-ap-south-1/latest/install /home/ec2-user/install --region ap-south-1
    chmod +x /home/ec2-user/install
    /home/ec2-user/install auto

    # 3. FIX: Dynamic DNS Mapping
    ENDPOINT_IP=$(nslookup codedeploy-commands-secure.ap-south-1.amazonaws.com | grep 'Address' | tail -n1 | awk '{print $2}')
    echo "$ENDPOINT_IP codedeploy-commands.ap-south-1.amazonaws.com" >> /etc/hosts

    # 4. FIX: Create SSL Bypass Environment File
    mkdir -p /etc/sysconfig
    cat <<'ENV' > /etc/sysconfig/codedeploy-agent
    RUBYOPT='-r openssl -e OpenSSL::SSL::VERIFY_MODE=OpenSSL::SSL::VERIFY_NONE'
    ENV

    # 5. FIX: Inject EnvironmentFile into Systemd Service
    SERVICE_FILE="/usr/lib/systemd/system/codedeploy-agent.service"
    if ! grep -q "EnvironmentFile=/etc/sysconfig/codedeploy-agent" "$SERVICE_FILE"; then
        sed -i '/\[Service\]/a EnvironmentFile=/etc/sysconfig/codedeploy-agent' "$SERVICE_FILE"
    fi

    # 6. FIX: Apply Source Code Patch
    POLLER_FILE="/opt/codedeploy-agent/lib/instance_agent/plugins/codedeploy/command_poller.rb"
    sed -i 's/ssl_verify_mode: :peer/ssl_verify_mode: :none/g' "$POLLER_FILE"
    sed -i '65s/^/#/' "$POLLER_FILE"

    # 7. Add config file setting
    echo ":ssl_verify_mode: none" >> /etc/codedeploy-agent/conf/codedeployagent.yml

    # 8. Final Clean Restart
    systemctl daemon-reload
    systemctl restart codedeploy-agent
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = { Name = "ecom-app-instance" }
  }
}

############################################
# 3. Auto Scaling Groups
############################################
resource "aws_autoscaling_group" "app" {
  for_each            = toset(["customer", "products", "shopping"])
  
  # Removed the escaping so Terraform correctly interpolates the service names
  name                = "${each.key}-asg"
  
  vpc_zone_identifier = var.private_subnets
  desired_capacity    = 1
  min_size            = 1
  max_size            = 2

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