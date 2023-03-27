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
  execution_role_arn       = var.ecs_task_execution_role
  task_role_arn            = var.ecs_task_role
  container_definitions = jsonencode([{
    name      = "${var.name}-container-${var.environment}"
    image     = "${var.aws_ecr_repository_url_frontend}:prod"
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
    image     = "${var.aws_ecr_repository_url_backend}:prod"
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
    target_group_arn = var.aws_alb_target_group_arn_frontend
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
    target_group_arn = var.aws_alb_target_group_arn_backend
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
