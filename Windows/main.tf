provider "aws" {
  region = "us-west-2"
}

# Launch Configuration for Windows Server
resource "aws_launch_configuration" "windows" {
  name          = "windows-launch-configuration"
  image_id      = "ami-0b69ea66ff7391e80"  # Windows Server 2019 AMI ID
  instance_type = "t3.medium"
  key_name      = "poc-aug"

  security_groups = [aws_security_group.instance.id]

  user_data = <<-EOF
              <powershell>
              # Update and install IIS
              Install-WindowsFeature -name Web-Server -IncludeManagementTools
              
              # Start IIS
              Start-Service -Name W3SVC

              # Create a simple HTML page
              echo 'Hello, World! This is a Windows Server instance.' | Out-File -FilePath C:\inetpub\wwwroot\index.html
              </powershell>
              EOF
}

# Auto Scaling Group for Windows Server
resource "aws_autoscaling_group" "windows_asg" {
  desired_capacity     = 2
  max_size             = 5
  min_size             = 1
  vpc_zone_identifier  = [
    aws_subnet.subnet_a.id,
    aws_subnet.subnet_b.id,
    aws_subnet.subnet_c.id,
  ]

  launch_configuration = aws_launch_configuration.windows.id

  tag {
    key                 = "Name"
    value               = "windows-instance"
    propagate_at_launch = true
  }
}

# CloudWatch Alarm for High CPU Utilization
resource "aws_cloudwatch_metric_alarm" "windows_cpu_alarm_high" {
  alarm_name                = "windows_cpu_alarm_high"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "2"
  metric_name               = "CPUUtilization"
  namespace                 = "AWS/EC2"
  period                    = "60"
  statistic                 = "Average"
  threshold                 = "70"
  alarm_description         = "This metric monitors high CPU utilization"
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.windows_asg.name
  }
  alarm_actions             = [aws_autoscaling_policy.windows_scale_up_policy.arn]
  insufficient_data_actions = []
  ok_actions                = []
}

# CloudWatch Alarm for Low CPU Utilization
resource "aws_cloudwatch_metric_alarm" "windows_cpu_alarm_low" {
  alarm_name                = "windows_cpu_alarm_low"
  comparison_operator       = "LessThanOrEqualToThreshold"
  evaluation_periods        = "2"
  metric_name               = "CPUUtilization"
  namespace                 = "AWS/EC2"
  period                    = "60"
  statistic                 = "Average"
  threshold                 = "20"
  alarm_description         = "This metric monitors low CPU utilization"
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.windows_asg.name
  }
  alarm_actions             = [aws_autoscaling_policy.windows_scale_down_policy.arn]
  insufficient_data_actions = []
  ok_actions                = []
}

# Scale-Up Policy for Windows Server
resource "aws_autoscaling_policy" "windows_scale_up_policy" {
  name                   = "windows_scale_up_policy"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.windows_asg.name
}

# Scale-Down Policy for Windows Server
resource "aws_autoscaling_policy" "windows_scale_down_policy" {
  name                   = "windows_scale_down_policy"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.windows_asg.name
}

