variable "name" {
  description = "the name of your stack, e.g. \"demo\""
}

variable "environment" {
  description = "the name of your environment, e.g. \"prod\""
}

variable "backend" {
  description = "Turn on Backend ECS service and related infra"
  default     = false
}

variable "frontend" {
  description = "Turn on frontend ECS service and related infra"
  default     = true
}

variable "vpc_id" {
  description = "vpc id of the region"
  default     = "vpc-b5351ddd"
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
