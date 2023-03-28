#=======================================================================
#                               IAM
#=======================================================================
resource "aws_iam_policy" "s3_env_access" {
  name        = "${var.name}-s3-env-access-${var.environment}"
  path        = "/"
  description = "s3 ecs env access"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",
        ]
        Effect   = "Allow"
        Resource = ["arn:aws:s3:::${var.name}-env/*", "arn:aws:s3:::${var.name}-env"]
      },
      {
        Action = [
          "s3:GetBucketLocation",
        ]
        Effect   = "Allow"
        Resource = ["arn:aws:s3:::${var.name}-env"]
      }
    ]
  })
}


data "aws_iam_policy_document" "ecs_trust_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2_role" {
  name               = "${var.name}-ec2-role-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.ecs_trust_policy.json
  tags = {
    "name"        = "${var.name}"
    "environment" = "${var.environment}"
  }
}


resource "aws_iam_instance_profile" "ec2_instance_role" {
  name = "${var.name}-ec2-instance-role-${var.environment}"
  role = aws_iam_role.ec2_role.name
  tags = {
    "name"        = "${var.name}"
    "environment" = "${var.environment}"
  }
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.name}-ecs-TaskExecutionRole-${var.environment}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role" "ecs_task_role" {
  name = "${var.name}-ecs-TaskRole-${var.environment}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ecs-task-execution-role-policy-attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "ec2-instance-role-role-policy-attachment" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_role_policy_attachment" "ecs-task-execution-role-policy-cloudwatch" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchFullAccess"
}

resource "aws_iam_role_policy_attachment" "ecs-task-execution-s3-policy-attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = aws_iam_policy.s3_env_access.arn
}

resource "aws_iam_role_policy_attachment" "ecs-task-s3-policy-attachment" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.s3_env_access.arn
}

#=======================================================================
#                               ALB
#=======================================================================

resource "aws_lb" "frontend" {
  name                       = "${var.name}-alb-frontend-${var.environment}"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = aws_security_group.alb.id
  subnets                    = var.subnets
  enable_deletion_protection = false
  count                      = var.frontend ? 1 : 0
  tags = {
    Name        = "${var.name}-alb-frontend-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_lb_target_group" "frontend" {
  name                 = "${var.name}-tg-frontend-${var.environment}"
  port                 = 80
  protocol             = "HTTP"
  vpc_id               = var.vpc_id
  deregistration_delay = 120
  count                = var.frontend ? 1 : 0

  health_check {
    healthy_threshold   = "3"
    interval            = "30"
    protocol            = "HTTP"
    matcher             = "200"
    timeout             = "3"
    path                = var.health_check_path_frontend
    unhealthy_threshold = "2"
  }

  tags = {
    Name        = "${var.name}-tg-frontend-${var.environment}"
    Environment = var.environment
  }
}

# Redirect to https listener
resource "aws_lb_listener" "frontendhttp" {
  load_balancer_arn = aws_lb.frontend[0].id
  port              = 80
  protocol          = "HTTP"
  count             = var.frontend ? 1 : 0
  default_action {
    type = "redirect"

    redirect {
      port        = 443
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# Redirect traffic to target group
resource "aws_lb_listener" "frontendhttps" {
  load_balancer_arn = aws_lb.frontend[0].id
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-Ext-2018-06"
  certificate_arn   = var.alb_tls_cert_arn
  count             = var.frontend ? 1 : 0

  default_action {
    target_group_arn = aws_lb_target_group.frontend[0].id
    type             = "forward"
  }
}

resource "aws_lb" "backend" {
  name                       = "${var.name}-alb-backend-${var.environment}"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = aws_security_group.alb.id
  subnets                    = var.subnets
  enable_deletion_protection = false
  count                      = var.backend ? 1 : 0

  tags = {
    Name        = "${var.name}-alb-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_lb_target_group" "backend" {
  name                 = "${var.name}-tg-backend-${var.environment}"
  port                 = 80
  protocol             = "HTTP"
  vpc_id               = var.vpc_id
  deregistration_delay = 120
  count                = var.backend ? 1 : 0
  health_check {
    healthy_threshold   = "3"
    interval            = "30"
    protocol            = "HTTP"
    matcher             = "200"
    timeout             = "3"
    path                = var.health_check_path_backend
    unhealthy_threshold = "2"
  }

  tags = {
    Name        = "${var.name}-tg-${var.environment}"
    Environment = var.environment
  }
}

# Redirect to https listener
resource "aws_lb_listener" "backendhttp" {
  load_balancer_arn = aws_lb.backend[0].id
  port              = 80
  protocol          = "HTTP"
  count             = var.backend ? 1 : 0
  default_action {
    type = "redirect"

    redirect {
      port        = 443
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# Redirect traffic to target group
resource "aws_lb_listener" "backendhttps" {
  load_balancer_arn = aws_lb.backend[0].id
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-Ext-2018-06"
  certificate_arn   = var.alb_tls_cert_arn
  count             = var.backend ? 1 : 0

  default_action {
    target_group_arn = aws_lb_target_group.backend[0].id
    type             = "forward"
  }
}

#=======================================================================
#                               ASG
#=======================================================================

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
    name = aws_iam_instance_profile.ec2_instance_role.name
  }
  vpc_security_group_ids = aws_security_group.ec2.id
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

#=======================================================================
#                               ECR
#=======================================================================
resource "aws_ecr_repository" "frontend" {
  name                 = "${var.name}-${var.environment}-frontend"
  image_tag_mutability = "MUTABLE"
  count                = var.frontend ? 1 : 0
  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "backend" {
  name                 = "${var.name}-${var.environment}-backend"
  image_tag_mutability = "MUTABLE"
  count                = var.backend ? 1 : 0
  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "backend" {
  repository = aws_ecr_repository.backend[0].name
  count      = var.backend ? 1 : 0
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "keep last 10 images"
      action = {
        type = "expire"
      }
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
    }]
  })
}

resource "aws_ecr_lifecycle_policy" "frontend" {
  repository = aws_ecr_repository.frontend[0].name
  count      = var.frontend ? 1 : 0
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "keep last 10 images"
      action = {
        type = "expire"
      }
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
    }]
  })
}
#=======================================================================
#                               ECS
#=======================================================================
resource "aws_cloudwatch_log_group" "frontend" {
  name              = "/ecs/${var.name}-frontend-${var.environment}"
  retention_in_days = 90
  count             = var.frontend ? 1 : 0
  tags = {
    Name        = "${var.name}-frontend-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_log_group" "backend" {
  name              = "/ecs/${var.name}-backend-${var.environment}"
  retention_in_days = 90
  count             = var.backend ? 1 : 0
  tags = {
    Name        = "${var.name}-backend-${var.environment}"
    Environment = var.environment
  }
}

# Task Definition
resource "aws_ecs_task_definition" "frontendTask" {
  family                   = "${var.name}-frontend-task-${var.environment}"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  cpu                      = var.container_cpu
  memory                   = var.container_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn
  container_definitions = jsonencode([{
    name      = "${var.name}-container-${var.environment}"
    image     = "${var.frontend == 1 ? "${var.aws_ecr_repository_url_frontend}:prod" : null}"
    essential = true
    environment = [{
      name  = "LOG_LEVEL",
      value = "DEBUG"
    }]
    environmentFiles = [{
      type  = "s3",
      value = "arn:aws:s3:::${var.name}-env/frontend/.env"
    }]
    portMappings = [{
      protocol      = "tcp"
      containerPort = var.container_port_frontend
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.frontend[0].name
        awslogs-stream-prefix = "ecs"
        awslogs-region        = var.region
      }
    }
  }])
  count = var.frontend ? 1 : 0
  tags = {
    Name        = "${var.name}-frontend-task-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_ecs_task_definition" "backendTask" {
  family                   = "${var.name}-backend-task-${var.environment}"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  cpu                      = var.container_cpu
  memory                   = var.container_memory
  execution_role_arn       = var.ecs_task_execution_role
  task_role_arn            = var.ecs_task_role
  container_definitions = jsonencode([{
    name      = "${var.name}-container-${var.environment}"
    image     = "${var.backend == 1 ? "${var.aws_ecr_repository_url_backend}:prod" : null}"
    essential = true
    environment = [{
      name  = "LOG_LEVEL",
      value = "DEBUG"
    }]
    environmentFiles = [{
      type  = "s3",
      value = "arn:aws:s3:::${var.name}-env/backend/.env"
    }]
    portMappings = [{
      protocol      = "tcp"
      containerPort = var.container_port_backend
      name          = "${var.name}-container-${var.environment}-tcp"
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.backend[0].name
        awslogs-stream-prefix = "ecs"
        awslogs-region        = var.region
      }
    }
  }])
  count = var.backend ? 1 : 0
  tags = {
    Name        = "${var.name}-task-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_ecs_cluster" "main" {
  name = "${var.name}-cluster-${var.environment}"
  tags = {
    Name        = "${var.name}-cluster-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_ecs_service" "frontendService" {
  name                               = "${var.name}-frontend-service-${var.environment}"
  cluster                            = aws_ecs_cluster.main.id
  task_definition                    = aws_ecs_task_definition.frontendTask[0].arn
  desired_count                      = var.service_desired_count
  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200
  health_check_grace_period_seconds  = 60
  scheduling_strategy                = "REPLICA"
  count                              = var.frontend ? 1 : 0

  load_balancer {
    target_group_arn = var.frontend == 1 ? "${aws_lb_target_group.frontend[0].arn}" : null
    container_name   = "${var.name}-container-${var.environment}"
    container_port   = var.container_port_frontend
  }

  # we ignore task_definition changes as the revision changes on deploy
  # of a new version of the application
  # desired_count is ignored as it can change due to autoscaling policy
  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }
}

resource "aws_ecs_service" "backendService" {
  name                               = "${var.name}-backend-service-${var.environment}"
  cluster                            = aws_ecs_cluster.main.id
  task_definition                    = aws_ecs_task_definition.backendTask[0].arn
  desired_count                      = var.service_desired_count
  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200
  health_check_grace_period_seconds  = 60
  scheduling_strategy                = "REPLICA"
  count                              = var.backend ? 1 : 0
  load_balancer {
    target_group_arn = var.backend == 1 ? "${aws_lb_target_group.backend[0].arn}" : null
    container_name   = "${var.name}-container-${var.environment}"
    container_port   = var.container_port_backend
  }

  # we ignore task_definition changes as the revision changes on deploy
  # of a new version of the application
  # desired_count is ignored as it can change due to autoscaling policy
  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }
}


#======================================================================
#  Auto Scaling Task Backend
#======================================================================

resource "aws_appautoscaling_target" "dev_to_target_backend" {
  max_capacity       = 10
  min_capacity       = 2
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.backendService[0].name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
  count              = var.backend ? 1 : 0
}

resource "aws_appautoscaling_policy" "dev_to_memory" {
  name               = "high memory utilization"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.dev_to_target_backend[0].resource_id
  scalable_dimension = aws_appautoscaling_target.dev_to_target_backend[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.dev_to_target_backend[0].service_namespace
  count              = var.backend ? 1 : 0
  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }

    target_value = 80
  }
}

resource "aws_appautoscaling_policy" "dev_to_cpu" {
  name               = "high cpu utilization"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.dev_to_target_backend[0].resource_id
  scalable_dimension = aws_appautoscaling_target.dev_to_target_backend[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.dev_to_target_backend[0].service_namespace
  count              = var.backend ? 1 : 0
  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    target_value = 60
  }
}


#======================================================================
#  Auto Scaling Task Frontend
#======================================================================

resource "aws_appautoscaling_target" "dev_to_target_front" {
  max_capacity       = 10
  min_capacity       = 2
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.frontendService[0].name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
  count              = var.frontend ? 1 : 0
}

resource "aws_appautoscaling_policy" "dev_to_memory_front" {
  name               = "high memory utilization"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.dev_to_target_front[0].resource_id
  scalable_dimension = aws_appautoscaling_target.dev_to_target_front[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.dev_to_target_front[0].service_namespace
  count              = var.frontend ? 1 : 0
  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }

    target_value = 80
  }
}

resource "aws_appautoscaling_policy" "dev_to_cpu_front" {
  name               = "high cpu utilization"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.dev_to_target_front[0].resource_id
  scalable_dimension = aws_appautoscaling_target.dev_to_target_front[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.dev_to_target_front[0].service_namespace
  count              = var.frontend ? 1 : 0
  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    target_value = 60
  }
}
#=======================================================================
#                               S3
#=======================================================================
resource "aws_s3_bucket" "env" {
  bucket = "${var.name}-env"
}


#=======================================================================
#                               SG
#=======================================================================

# Internet to ALB
resource "aws_security_group" "alb" {
  name        = "${var.name}-sg-alb-${var.environment}"
  vpc_id      = var.vpc_id
  description = "loadbalancer sg"

  ingress {
    protocol         = "tcp"
    from_port        = 80
    to_port          = 80
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    protocol         = "tcp"
    from_port        = 443
    to_port          = 443
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    protocol         = "-1"
    from_port        = 0
    to_port          = 0
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name        = "${var.name}-sg-alb-${var.environment}"
    Environment = var.environment
  }
}



resource "aws_security_group_rule" "ec2_alb" {
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = 1024
  to_port                  = 65535
  security_group_id        = aws_security_group.alb.id
  source_security_group_id = aws_security_group.ec2.id
  depends_on = [
    aws_security_group.ec2
  ]
}


resource "aws_security_group" "ec2" {
  name        = "${var.name}-sg-ec2-${var.environment}"
  vpc_id      = var.vpc_id
  description = "ec2 sg"


  ingress {
    protocol        = "tcp"
    from_port       = 1024
    to_port         = 65535
    security_groups = ["${aws_security_group.alb.id}"]
  }

  ingress {
    protocol         = "tcp"
    from_port        = 443
    to_port          = 443
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    protocol         = "-1"
    from_port        = 0
    to_port          = 0
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name        = "${var.name}-sg-ec2-${var.environment}"
    Environment = var.environment
  }

}
