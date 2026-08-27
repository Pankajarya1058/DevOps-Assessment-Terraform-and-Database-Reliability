output "alb_dns_name" {
  description = "Public DNS name of the ALB - hit this in a browser once the service is up"
  value       = aws_lb.main.dns_name
}

output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_app_subnet_ids" {
  value = aws_subnet.private_app[*].id
}

output "private_db_subnet_ids" {
  value = aws_subnet.private_db[*].id
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.main.name
}

output "rds_endpoint" {
  description = "RDS endpoint (reachable only from within the VPC / ECS tasks)"
  value       = aws_db_instance.main.address
  sensitive   = true
}

output "db_secret_arn" {
  description = "Secrets Manager ARN holding DB connection details"
  value       = aws_secretsmanager_secret.db_credentials.arn
}
