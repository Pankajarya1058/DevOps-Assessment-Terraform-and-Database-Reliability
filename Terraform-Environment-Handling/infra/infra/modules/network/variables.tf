variable "project_name" {
  description = "Name prefix used for tagging and resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name, e.g. dev or prod"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "az_count" {
  description = "Number of Availability Zones to spread subnets across"
  type        = number
  default     = 2
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (one per AZ)"
  type        = list(string)
}

variable "private_app_subnet_cidrs" {
  description = "CIDR blocks for private application (ECS) subnets (one per AZ)"
  type        = list(string)
}

variable "private_db_subnet_cidrs" {
  description = "CIDR blocks for private database (RDS) subnets (one per AZ)"
  type        = list(string)
}

variable "single_nat_gateway" {
  description = "If true, create just one NAT Gateway (cheaper, used for dev). If false, one per AZ for HA (used for prod)."
  type        = bool
  default     = false
}

variable "container_port" {
  description = "Port the ALB target group forwards to on ECS tasks"
  type        = number
}
