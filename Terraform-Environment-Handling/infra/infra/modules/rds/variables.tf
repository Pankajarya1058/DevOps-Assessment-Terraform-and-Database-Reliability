variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_db_subnet_ids" {
  description = "Private DB subnet IDs from the network module"
  type        = list(string)
}

variable "ecs_tasks_security_group_id" {
  description = "Security group ID of ECS tasks from the ecs module - RDS allows inbound ONLY from this SG"
  type        = string
}

variable "db_engine" {
  type    = string
  default = "postgres"
  validation {
    condition     = contains(["postgres", "mysql"], var.db_engine)
    error_message = "db_engine must be either \"postgres\" or \"mysql\"."
  }
}

variable "db_engine_version" {
  type = string
}

variable "db_instance_class" {
  description = "RDS instance class - sized per environment"
  type        = string
}

variable "db_allocated_storage" {
  description = "Allocated storage in GB - sized per environment"
  type        = number
}

variable "db_max_allocated_storage" {
  description = "Upper bound for storage autoscaling - sized per environment"
  type        = number
  default     = null
}

variable "db_name" {
  type    = string
  default = "appdb"
}

variable "db_username" {
  type      = string
  default   = "appadmin"
  sensitive = true
}

variable "db_multi_az" {
  description = "Multi-AZ for HA - true for prod, false for dev"
  type        = bool
}

variable "backup_retention_period" {
  description = "Backup retention in days - shorter for dev, longer for prod"
  type        = number
}

variable "deletion_protection" {
  description = "Deletion protection - false for dev, true for prod"
  type        = bool
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot on destroy - true for dev, false for prod"
  type        = bool
}

variable "performance_insights_enabled" {
  description = "Enable Performance Insights - typically off for dev, on for prod"
  type        = bool
  default     = false
}
