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
