variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "vpc_id" {
  description = "VPC ID from the network module"
  type        = string
}

variable "private_app_subnet_ids" {
  description = "Private application subnet IDs from the network module"
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "ALB security group ID from the network module - ECS tasks accept traffic only from this SG"
  type        = string
}

variable "target_group_arn" {
  description = "ALB target group ARN from the network module"
  type        = string
}

variable "listener_arn" {
  description = "ALB listener ARN from the network module (service depends on it existing first)"
  type        = string
}

variable "container_image" {
  type = string
}

variable "container_port" {
  type = number
}

variable "task_cpu" {
  description = "Fargate task CPU units - sized per environment"
  type        = string
}

variable "task_memory" {
  description = "Fargate task memory (MiB) - sized per environment"
  type        = string
}

variable "desired_count" {
  description = "Desired number of ECS tasks - sized per environment"
  type        = number
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days - shorter for dev, longer for prod"
  type        = number
  default     = 14
}

variable "db_secret_arn" {
  description = "Secrets Manager ARN holding DB connection details, injected into the container as env vars"
  type        = string
}
