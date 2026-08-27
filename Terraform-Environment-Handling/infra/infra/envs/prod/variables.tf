variable "aws_region" {
  type = string
}

variable "project_name" {
  type = string
}

variable "environment" {
  type    = string
  default = "prod"
}

# --- Network sizing ---

variable "vpc_cidr" {
  type = string
}

variable "az_count" {
  type    = number
  default = 2
}

variable "public_subnet_cidrs" {
  type = list(string)
}

variable "private_app_subnet_cidrs" {
  type = list(string)
}

variable "private_db_subnet_cidrs" {
  type = list(string)
}

variable "single_nat_gateway" {
  type    = bool
  default = false # prod: one NAT per AZ for HA
}

# --- ECS sizing ---

variable "container_image" {
  type = string
}

variable "container_port" {
  type    = number
  default = 80
}

variable "task_cpu" {
  type = string
}

variable "task_memory" {
  type = string
}

variable "desired_count" {
  type = number
}

variable "log_retention_days" {
  type    = number
  default = 90 # prod: longer retention
}

# --- RDS sizing ---

variable "db_engine" {
  type    = string
  default = "postgres"
}

variable "db_engine_version" {
  type = string
}

variable "db_instance_class" {
  type = string
}

variable "db_allocated_storage" {
  type = number
}

variable "db_max_allocated_storage" {
  type    = number
  default = null
}

variable "db_multi_az" {
  type    = bool
  default = true # prod: HA
}

variable "db_backup_retention_period" {
  type    = number
  default = 30 # prod: long backup retention
}

variable "db_deletion_protection" {
  type    = bool
  default = true # prod: protect against accidental destroy
}

variable "db_skip_final_snapshot" {
  type    = bool
  default = false # prod: always take a final snapshot
}

variable "db_performance_insights_enabled" {
  type    = bool
  default = true
}
