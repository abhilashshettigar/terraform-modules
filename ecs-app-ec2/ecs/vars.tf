variable "name" {
  description = "the name of your stack, e.g. \"demo\""
}

variable "environment" {
  description = "the name of your environment, e.g. \"prod\""
}


variable "container_cpu" {

}

variable "container_memory" {

}

variable "aws_ecr_repository_url_frontend" {

}

variable "container_port_frontend" {

}

variable "region" {

}

variable "aws_ecr_repository_url_backend" {

}

variable "container_port_backend" {

}

variable "service_desired_count" {

}

variable "ecs_task_execution_role" {

}

variable "ecs_task_role" {

}

variable "aws_alb_target_group_arn_frontend" {

}

variable "aws_alb_target_group_arn_backend" {

}

variable "backend" {
  description = "Turn on Backend ECS service and related infra"
}

variable "frontend" {
  description = "Turn on frontend ECS service and related infra"
}
