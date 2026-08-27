module "network" {
  source = "../../modules/network"

  project_name              = var.project_name
  environment               = var.environment
  vpc_cidr                  = var.vpc_cidr
  az_count                  = var.az_count
  public_subnet_cidrs       = var.public_subnet_cidrs
  private_app_subnet_cidrs  = var.private_app_subnet_cidrs
  private_db_subnet_cidrs   = var.private_db_subnet_cidrs
  single_nat_gateway        = var.single_nat_gateway
  container_port            = var.container_port
}

module "rds" {
  source = "../../modules/rds"

  project_name          = var.project_name
  environment           = var.environment
  vpc_id                = module.network.vpc_id
  private_db_subnet_ids = module.network.private_db_subnet_ids

  ecs_tasks_security_group_id = module.ecs.ecs_tasks_security_group_id

  db_engine                    = var.db_engine
  db_engine_version            = var.db_engine_version
  db_instance_class            = var.db_instance_class
  db_allocated_storage         = var.db_allocated_storage
  db_max_allocated_storage     = var.db_max_allocated_storage
  db_multi_az                  = var.db_multi_az
  backup_retention_period      = var.db_backup_retention_period
  deletion_protection          = var.db_deletion_protection
  skip_final_snapshot          = var.db_skip_final_snapshot
  performance_insights_enabled = var.db_performance_insights_enabled
}

module "ecs" {
  source = "../../modules/ecs"

  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region

  vpc_id                  = module.network.vpc_id
  private_app_subnet_ids  = module.network.private_app_subnet_ids
  alb_security_group_id   = module.network.alb_security_group_id
  target_group_arn        = module.network.target_group_arn
  listener_arn            = module.network.listener_arn

  container_image = var.container_image
  container_port  = var.container_port
  task_cpu        = var.task_cpu
  task_memory     = var.task_memory
  desired_count   = var.desired_count

  log_retention_days = var.log_retention_days
  db_secret_arn       = module.rds.db_secret_arn
}
