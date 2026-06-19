locals {
  name_prefix = "petclinic-${var.environment}"
  common_tags = merge(
    {
      Project     = "petclinic"
      Environment = var.environment
      ManagedBy   = "terraform"
    },
    var.tags
  )
}

# ---------------------------------------------------------------------------
# Master Password
# ---------------------------------------------------------------------------
resource "random_password" "master" {
  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# ---------------------------------------------------------------------------
# DB Parameter Group
# ---------------------------------------------------------------------------
resource "aws_db_parameter_group" "rds" {
  name        = "${local.name_prefix}-mysql8-0"
  family      = "mysql8.0"
  description = "Custom parameter group for ${local.name_prefix}"

  parameter {
    name         = "character_set_server"
    value        = "utf8mb4"
    apply_method = "immediate"
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-mysql8-0" })
}

# ---------------------------------------------------------------------------
# DB Subnet Group
# ---------------------------------------------------------------------------
resource "aws_db_subnet_group" "rds" {
  name        = "${local.name_prefix}-rds-subnet-group"
  description = "Subnet group for ${local.name_prefix} RDS"
  subnet_ids  = var.subnet_ids

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-rds-subnet-group" })
}

# ---------------------------------------------------------------------------
# RDS Instance
# ---------------------------------------------------------------------------
resource "aws_db_instance" "main" {
  identifier     = "${local.name_prefix}-mysql"
  engine         = "mysql"
  engine_version = "8.0"
  instance_class = var.instance_class

  db_name  = var.db_name
  username = var.db_username
  password = random_password.master.result

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp2"
  storage_encrypted     = true

  multi_az = var.multi_az

  db_subnet_group_name   = aws_db_subnet_group.rds.name
  vpc_security_group_ids = [var.rds_security_group_id]
  parameter_group_name   = aws_db_parameter_group.rds.name

  backup_retention_period = 0
  skip_final_snapshot     = var.skip_final_snapshot
  publicly_accessible     = false
  deletion_protection     = false

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-mysql" })
}

# ---------------------------------------------------------------------------
# Secrets Manager — RDS Credentials
# ---------------------------------------------------------------------------
resource "aws_secretsmanager_secret" "rds" {
  name        = "petclinic/${var.environment}/rds-credentials"
  description = "RDS credentials for ${local.name_prefix}"

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-rds-credentials" })
}

resource "aws_secretsmanager_secret_version" "rds" {
  secret_id = aws_secretsmanager_secret.rds.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.master.result
  })
}
