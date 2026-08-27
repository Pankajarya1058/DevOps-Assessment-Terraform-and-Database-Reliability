locals {
  db_port = var.db_engine == "postgres" ? 5432 : 3306
}

resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = aws_subnet.private_db[*].id

  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }
}

# Randomly generated master password, stored in Secrets Manager rather than
# in state as a plain variable.
resource "random_password" "db_master" {
  length           = 20
  special          = true
  override_special = "!#$%^&*()-_=+"
}

resource "aws_secretsmanager_secret" "db_credentials" {
  name = "${var.project_name}/rds/master-credentials"
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
  identifier     = "${var.project_name}-db"
  engine         = var.db_engine
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class

  allocated_storage = var.db_allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db_master.result
  port     = local.db_port

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  # Private only - no public access, no CIDR ingress on the SG either.
  publicly_accessible = false

  multi_az                   = var.db_multi_az
  backup_retention_period    = 7
  auto_minor_version_upgrade = true
  deletion_protection        = false # set true for real production use
  skip_final_snapshot        = true  # set false + add final_snapshot_identifier for prod

  tags = {
    Name = "${var.project_name}-db"
  }
}
