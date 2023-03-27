data "aws_ami" "default" {
  filter {
    name   = "name"
    values = ["amzn2-ami-ecs-hvm-2.0.202*-x86_64-ebs"]
  }

  most_recent = true
  owners      = ["amazon"]
}
resource "aws_launch_template" "ecs_launch_config" {
  image_id = data.aws_ami.default.id
  iam_instance_profile {
    name = var.instance_profile_role
  }
  vpc_security_group_ids = var.ec2_security_groups
  key_name               = var.pem_file_name
  instance_type          = var.instance_type
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 15
    }
  }
  user_data   = filebase64("./scripts/ecs.sh")
  name_prefix = "ECS-Instance-${var.name}-${var.environment}"
}

resource "aws_autoscaling_group" "ecs_asg" {
  name                = "${var.name}-autoscale-group-${var.environment}"
  vpc_zone_identifier = var.subnets
  launch_template {
    id      = aws_launch_template.ecs_launch_config.id
    version = "$Latest"
  }

  desired_capacity          = 2
  min_size                  = 2
  max_size                  = 5
  health_check_grace_period = 300
  health_check_type         = "EC2"

  tag {
    key                 = "Name"
    value               = "ECS-Instance-${var.name}-${var.environment}"
    propagate_at_launch = true
  }

}

resource "aws_autoscaling_policy" "web_policy_up" {
  name                   = "web_policy_up_ecs"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 120
  autoscaling_group_name = aws_autoscaling_group.ecs_asg.name
}

resource "aws_cloudwatch_metric_alarm" "web_cpu_alarm_up" {
  alarm_name          = "web_cpu_alarm_up_ecs"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "70"
  dimensions = {
    AutoScalingGroupName = "${aws_autoscaling_group.ecs_asg.name}"
  }
  alarm_description = "This metric monitor EC2 instance CPU utilization"
  alarm_actions     = ["${aws_autoscaling_policy.web_policy_up.arn}"]
}

resource "aws_autoscaling_policy" "web_policy_down" {
  name                   = "web_policy_down_ecs"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.ecs_asg.name
}

resource "aws_cloudwatch_metric_alarm" "web_cpu_alarm_down" {
  alarm_name          = "web_cpu_alarm_down_ecs"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "30"
  dimensions = {
    AutoScalingGroupName = "${aws_autoscaling_group.ecs_asg.name}"
  }
  alarm_description = "This metric monitor EC2 instance CPU utilization"
  alarm_actions     = ["${aws_autoscaling_policy.web_policy_down.arn}"]
}
