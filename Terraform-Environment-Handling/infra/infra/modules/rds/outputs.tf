output "db_instance_id" {
  value = aws_db_instance.main.id
}

output "db_endpoint" {
  description = "RDS endpoint (reachable only from within the VPC / ECS tasks)"
  value       = aws_db_instance.main.address
  sensitive   = true
}

output "db_port" {
  value = local.db_port
}

output "db_secret_arn" {
  description = "Secrets Manager ARN holding DB connection details - pass this into the ecs module"
  value       = aws_secretsmanager_secret.db_credentials.arn
}

output "rds_security_group_id" {
  value = aws_security_group.rds.id
}
