################################################################################
# terraform/modules/database/main.tf
# RDS MySQL 8.0 — free tier compatible, cifrado en reposo
################################################################################

# ------------------------------------------------------------------------------
# DB Subnet Group — RDS necesita minimo 2 AZs
# ------------------------------------------------------------------------------
resource "aws_db_subnet_group" "aws_3tier_db_subnet_group" {
  name        = "${var.project_name}-db-subnet-group"
  description = "Subnet group RDS: AZ1 primary + AZ2 dummy (requisito AWS)"
  subnet_ids  = var.db_subnet_ids

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-db-subnet-group"
  })
}

# ------------------------------------------------------------------------------
# RDS MySQL 8.0
# ------------------------------------------------------------------------------
resource "aws_db_instance" "aws_3tier_rds" {
  identifier = "${var.project_name}-mysql"

  # Motor
  engine         = "mysql"
  engine_version = "8.0"
  instance_class = "db.t3.micro"

  # Almacenamiento
  allocated_storage = 20
  storage_type      = "gp2"

  # storage_encrypted = true:
  #   Cifra datos en reposo con KMS (clave AWS gestionada por defecto).
  #   Cumple requisitos de seguridad sin coste adicional en gp2.
  storage_encrypted = true

  # Credenciales — valores inyectados via variables sensibles, nunca hardcodeados
  db_name  = var.db_name
  username = var.db_user
  password = var.db_password

  # Red
  db_subnet_group_name   = aws_db_subnet_group.aws_3tier_db_subnet_group.name
  vpc_security_group_ids = [var.sg_database_id]
  publicly_accessible    = false
  port                   = 3306

  # Alta disponibilidad — false (free tier; activar en produccion real)
  multi_az = false

  # Backups — 0 dias (free tier; aumentar en produccion)
  backup_retention_period = 0

  # Performance Insights — deshabilitado (free tier)
  performance_insights_enabled = false

  # Mantenimiento
  auto_minor_version_upgrade = true
  deletion_protection        = false

  # skip_final_snapshot = true:
  #   Al destruir con terraform destroy no intenta crear snapshot final.
  #   En entornos de desarrollo/lab esto acelera el ciclo de destroy/recreate.
  #   En produccion real cambiar a false y definir final_snapshot_identifier.
  skip_final_snapshot = true

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-rds-mysql"
  })
}
