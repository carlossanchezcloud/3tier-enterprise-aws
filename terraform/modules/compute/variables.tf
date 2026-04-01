################################################################################
# terraform/modules/compute/variables.tf
################################################################################

variable "project_name" {
  description = "Prefijo para nombrar todos los recursos"
  type        = string
}

variable "aws_region" {
  description = "Region AWS"
  type        = string
  default     = "us-east-1"
}

variable "vpc_id" {
  description = "ID de la VPC donde se despliegan los recursos compute"
  type        = string
}

variable "public_subnet_ids" {
  description = "IDs subredes públicas para el ALB público (AZ1 + AZ2)"
  type        = list(string)
}

variable "website_subnet_ids" {
  description = "IDs subredes privadas capa Website — ASG Website (AZ1 + AZ2)"
  type        = list(string)
}

variable "backend_subnet_ids" {
  description = "IDs subredes privadas capa Backend — ASG Backend (AZ1 + AZ2)"
  type        = list(string)
}

variable "sg_alb_public_id" {
  description = "ID SG ALB público (sg_alb_public)"
  type        = string
}

variable "sg_website_id" {
  description = "ID SG EC2 Website (sg_website)"
  type        = string
}

variable "sg_alb_internal_id" {
  description = "ID SG ALB interno (sg_alb_internal)"
  type        = string
}

variable "sg_backend_id" {
  description = "ID SG EC2 Backend (sg_backend)"
  type        = string
}

variable "rds_endpoint" {
  description = "Endpoint RDS (host:port) para inyectar en user_data backend"
  type        = string
}

variable "db_name" {
  description = "Nombre base de datos MySQL"
  type        = string
  default     = "salon_db"
}

variable "db_user" {
  description = "Usuario master RDS"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Password master RDS"
  type        = string
  sensitive   = true
}

variable "repo_url" {
  description = "URL HTTPS del repositorio GitHub para clonar en user_data"
  type        = string
}

variable "common_tags" {
  description = "Mapa de tags aplicados a todos los recursos"
  type        = map(string)
  default     = {}
}
