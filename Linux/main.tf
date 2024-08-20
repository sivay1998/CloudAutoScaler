provider "aws" {
  region = "us-west-2"
}

# VPC for the instances
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

# Create an Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

# Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

# Subnet A with auto-assign public IP
resource "aws_subnet" "subnet_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-west-2a"
  map_public_ip_on_launch = true
}

# Subnet B with auto-assign public IP
resource "aws_subnet" "subnet_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-west-2b"
  map_public_ip_on_launch = true
}

# Subnet C with auto-assign public IP
resource "aws_subnet" "subnet_c" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "us-west-2c"
  map_public_ip_on_launch = true
}

# Associate the route table with the subnets
resource "aws_route_table_association" "subnet_a" {
  subnet_id      = aws_subnet.subnet_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "subnet_b" {
  subnet_id      = aws_subnet.subnet_b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "subnet_c" {
  subnet_id      = aws_subnet.subnet_c.id
  route_table_id = aws_route_table.public.id
}

# Security Group associated with the VPC
resource "aws_security_group" "instance" {
  vpc_id      = aws_vpc.main.id
  name_prefix = "instance_sg"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
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
}

# Launch Configuration for the Auto Scaling Group
resource "aws_launch_configuration" "web" {
  name          = "web-launch-configuration"
  image_id      = "ami-074be47313f84fa38"
  instance_type = "t2.micro"
  key_name      = "poc-aug"

  security_groups = [aws_security_group.instance.id]

  user_data = <<-EOF
              #!/bin/bash
              sudo yum update -y
              sudo yum install httpd python3 -y
              sudo pip3 install flask
              sudo systemctl start httpd
              sudo systemctl enable httpd
              
              # Create a user with a password
              sudo useradd myuser
              echo "myuser:mypassword" | sudo chpasswd

              # Allow the user to use SSH
              sudo mkdir /home/myuser/.ssh
              sudo chown myuser:myuser /home/myuser/.ssh
              sudo chmod 700 /home/myuser/.ssh

              # Add the public key to the user's authorized_keys file
              sudo cp /home/ec2-user/.ssh/authorized_keys /home/myuser/.ssh/
              sudo chown myuser:myuser /home/myuser/.ssh/authorized_keys
              sudo chmod 600 /home/myuser/.ssh/authorized_keys

              # Start the Python Flask app
              echo 'from flask import Flask\nimport time\nimport threading\napp = Flask(__name__)\ndef burn_cpu():\n while True:\n pass\n@app.route("/")\ndef hello():\n threading.Thread(target=burn_cpu).start()\n return "Hello, World! This instance is under load."\nif __name__ == "__main__":\n app.run(host="0.0.0.0", port=80)' > /home/ec2-user/app.py
              sudo python3 /home/ec2-user/app.py &
              EOF
}

# Auto Scaling Group
resource "aws_autoscaling_group" "asg" {
  desired_capacity     = 2
  max_size             = 5
  min_size             = 1
  vpc_zone_identifier  = [
    aws_subnet.subnet_a.id,
    aws_subnet.subnet_b.id,
    aws_subnet.subnet_c.id,
  ]

  launch_configuration = aws_launch_configuration.web.id

  tag {
    key                 = "Name"
    value               = "web-instance"
    propagate_at_launch = true
  }
}

# CloudWatch Alarm for High CPU Utilization (Scale Up)
resource "aws_cloudwatch_metric_alarm" "cpu_alarm_high" {
  alarm_name                = "HighCPUUtilization"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = 1
  metric_name               = "CPUUtilization"
  namespace                 = "AWS/EC2"
  period                    = 60  # 60 seconds = 1 minute
  statistic                 = "Average"
  threshold                 = 30
  alarm_description         = "This metric monitors high CPU utilization"
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.asg.name
  }
  alarm_actions             = [aws_autoscaling_policy.scale_up_policy.arn]
  insufficient_data_actions = []
  ok_actions                = []
}

# CloudWatch Alarm for Low CPU Utilization (Scale Down)
resource "aws_cloudwatch_metric_alarm" "cpu_alarm_low" {
  alarm_name                = "LowCPUUtilization"
  comparison_operator       = "LessThanOrEqualToThreshold"
  evaluation_periods        = 1
  metric_name               = "CPUUtilization"
  namespace                 = "AWS/EC2"
  period                    = 60  # 60 seconds = 1 minute
  statistic                 = "Average"
  threshold                 = 20
  alarm_description         = "This metric monitors low CPU utilization"
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.asg.name
  }
  alarm_actions             = [aws_autoscaling_policy.scale_down_policy.arn]
  insufficient_data_actions = []
  ok_actions                = []
}

# Scale-Up Policy
resource "aws_autoscaling_policy" "scale_up_policy" {
  name                   = "scale_up_policy"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.asg.name
}

# Scale-Down Policy
resource "aws_autoscaling_policy" "scale_down_policy" {
  name                   = "scale_down_policy"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.asg.name
}


