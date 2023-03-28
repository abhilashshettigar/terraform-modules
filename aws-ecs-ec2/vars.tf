variable "name" {
  description = "the name of your stack, e.g. \"demo\""
}

variable "environment" {
  description = "the name of your environment, e.g. \"prod\""
}

variable "backend" {
  description = "Turn on Backend ECS service and related infra"
}

variable "frontend" {
  description = "Turn on frontend ECS service and related infra"
}

variable "vpc_id" {
  description = "vpc id of the region"
}

variable "health_check_path_frontend" {
  description = "health check route for frontend"
}

variable "health_check_path_backend" {
  description = "health check route for backend"
}

variable "pem_file_name" {
  description = "pem file name for ssh"
}

variable "instance_type" {
  description = "instance type for ecs"
}

variable "alb_tls_cert_arn" {
  description = "ceritifcate for loadbalancer"
}
variable "container_cpu" {
  description = "The number of cpu units used by the task"
}

variable "container_memory" {
  description = "The amount (in MiB) of memory used by the task"
}

variable "container_port_frontend" {
  description = "Port of container"
}

variable "container_port_backend" {
  description = "Port of container"
}
variable "service_desired_count" {
  description = "number of task running in a service"
}

variable "subnets" {

}

variable "region" {

}
