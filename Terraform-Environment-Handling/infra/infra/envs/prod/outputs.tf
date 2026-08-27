output "alb_dns_name" {
  value = module.network.alb_dns_name
}

output "vpc_id" {
  value = module.network.vpc_id
}

output "ecs_cluster_name" {
  value = module.ecs.cluster_name
}

output "rds_endpoint" {
  value     = module.rds.db_endpoint
  sensitive = true
}

output "db_secret_arn" {
  value = module.rds.db_secret_arn
}
