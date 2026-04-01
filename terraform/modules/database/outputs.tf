################################################################################
# terraform/modules/database/outputs.tf
################################################################################

output "rds_endpoint" {
  description = "Endpoint de conexion RDS (host:port)"
  value       = aws_db_instance.aws_3tier_rds.endpoint
}

output "rds_host" {
  description = "Hostname RDS (sin puerto)"
  value       = aws_db_instance.aws_3tier_rds.address
}

output "rds_port" {
  description = "Puerto RDS MySQL"
  value       = aws_db_instance.aws_3tier_rds.port
}

output "rds_db_name" {
  description = "Nombre de la base de datos"
  value       = aws_db_instance.aws_3tier_rds.db_name
}

output "rds_id" {
  description = "Identificador de la instancia RDS"
  value       = aws_db_instance.aws_3tier_rds.id
}

output "rds_arn" {
  description = "ARN de la instancia RDS"
  value       = aws_db_instance.aws_3tier_rds.arn
}
