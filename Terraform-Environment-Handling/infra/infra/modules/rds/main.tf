locals {
  name_prefix = "${var.project_name}-${var.environment}"
  db_port     = var.db_engine == "postgres" ? 5432 : 3306
}

# ---------------------------------------------------------------------------
# RDS security group - accepts traffic ONLY from the ECS tasks security
# group, on the DB port. No CIDR-based ingress at all.
# ---------------------------------------------------------------------------

resource "aws_security_group" "rds" {
  name        = "${local.name_prefix}-rds-sg"
  description = "Allow inbound DB traffic from ECS tasks only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "DB access from ECS tasks"
    from_port       = local.db_port
    to_port         = local.db_port
    protocol        = "tcp"
    security_groups = [var.ecs_tasks_security_group_id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${local.name_prefix}-rds-sg"
    Environment = var.environment
  }
}

resource "aws_db_subnet_group" "main" {
  name       = "${local.name_prefix}-db-subnet-group"
  subnet_ids = var.private_db_subnet_ids

  tags = {
    Name        = "${local.name_prefix}-db-subnet-group"
    Environment = var.environment
  }
}

# Randomly generated master password, stored in Secrets Manager rather than
# passed around as a plain variable.
resource "random_password" "db_master" {
  length           = 20
  special          = true
  override_special = "!#$%^&*()-_=+"
}

resource "aws_secretsmanager_secret" "db_credentials" {
  name = "${local.name_prefix}/rds/master-credentials"
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db_master.result
    engine   = var.db_engine
    host     = aws_db_instance.main.address
    port     = local.db_port
    dbname   = var.db_name
  })
}

resource "aws_db_instance" "main" {
  identifier     = "${local.name_prefix}-db"
  engine         = var.db_engine
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class

  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db_master.result
  port     = local.db_port

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  # Private only - no public access, no CIDR ingress on the SG either.
  publicly_accessible = false

  multi_az                            = var.db_multi_az
  backup_retention_period             = var.backup_retention_period
  performance_insights_enabled        = var.performance_insights_enabled
  auto_minor_version_upgrade          = true
  deletion_protection                 = var.deletion_protection
  skip_final_snapshot                 = var.skip_final_snapshot
  final_snapshot_identifier           = var.skip_final_snapshot ? null : "${local.name_prefix}-db-final-${var.environment}"

  tags = {
    Name        = "${local.name_prefix}-db"
    Environment = var.environment
  }
}
