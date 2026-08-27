output "cluster_name" {
  value = aws_ecs_cluster.main.name
}

output "cluster_arn" {
  value = aws_ecs_cluster.main.arn
}

output "service_name" {
  value = aws_ecs_service.app.name
}

output "task_definition_arn" {
  value = aws_ecs_task_definition.app.arn
}

output "ecs_tasks_security_group_id" {
  description = "Security group ID attached to ECS tasks - pass this to the rds module so RDS can allow ingress from it"
  value       = aws_security_group.ecs_tasks.id
}
