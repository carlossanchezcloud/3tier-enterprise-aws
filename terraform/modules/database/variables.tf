################################################################################
# terraform/modules/database/variables.tf
################################################################################

variable "project_name" {
  description = "Prefijo para nombrar todos los recursos"
  type        = string
}

variable "db_name" {
  description = "Nombre de la base de datos MySQL"
  type        = string
  default     = "salon_db"
}

variable "db_user" {
  description = "Usuario master RDS"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Password master RDS — nunca hardcodear, pasar siempre como variable sensible"
  type        = string
  sensitive   = true
}

variable "db_subnet_ids" {
  description = "Lista de IDs de subredes para el DB subnet group (minimo 2 AZs)"
  type        = list(string)
}

variable "sg_database_id" {
  description = "ID del Security Group para RDS"
  type        = string
}

variable "common_tags" {
  description = "Mapa de tags aplicados a todos los recursos"
  type        = map(string)
  default     = {}
}
