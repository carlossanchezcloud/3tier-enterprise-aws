################################################################################
# terraform/environments/prod/variables.tf
################################################################################

variable "aws_region" {
  description = "Region AWS para el despliegue"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefijo snake_case para todos los recursos"
  type        = string
  default     = "aws_3tier"
}

# ------------------------------------------------------------------------------
# Red — CIDRs por capa (8 subredes: 2 pub + 2 website + 2 backend + 2 db)
# ------------------------------------------------------------------------------
variable "vpc_cidr" {
  description = "CIDR block de la VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_az1_cidr" {
  description = "CIDR subred publica AZ1 (ALB + NAT Instance)"
  type        = string
  default     = "10.0.1.0/24"
}

variable "public_subnet_az2_cidr" {
  description = "CIDR subred publica AZ2 (ALB — requisito AWS)"
  type        = string
  default     = "10.0.2.0/24"
}

variable "website_subnet_az1_cidr" {
  description = "CIDR subred privada Website AZ1"
  type        = string
  default     = "10.0.11.0/24"
}

variable "website_subnet_az2_cidr" {
  description = "CIDR subred privada Website AZ2"
  type        = string
  default     = "10.0.12.0/24"
}

variable "backend_subnet_az1_cidr" {
  description = "CIDR subred privada Backend AZ1"
  type        = string
  default     = "10.0.21.0/24"
}

variable "backend_subnet_az2_cidr" {
  description = "CIDR subred privada Backend AZ2"
  type        = string
  default     = "10.0.22.0/24"
}

variable "db_subnet_az1_cidr" {
  description = "CIDR subred DB AZ1 (RDS primary)"
  type        = string
  default     = "10.0.31.0/24"
}

variable "db_subnet_az2_cidr" {
  description = "CIDR subred DB AZ2 (failover subnet — requisito AWS)"
  type        = string
  default     = "10.0.32.0/24"
}

# ------------------------------------------------------------------------------
# Base de datos — SENSIBLES: valores reales en terraform.tfvars (.gitignore)
# ------------------------------------------------------------------------------
variable "db_name" {
  description = "Nombre de la base de datos MySQL"
  type        = string
  default     = "salon_db"
}

variable "db_user" {
  description = "Usuario master RDS — sensible"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Password master RDS — sensible, nunca en codigo ni logs"
  type        = string
  sensitive   = true
}

# ------------------------------------------------------------------------------
# Aplicacion
# ------------------------------------------------------------------------------
variable "repo_url" {
  description = "URL HTTPS del repositorio GitHub"
  type        = string
  default     = "https://github.com/carlossanchezcloud/3tier-enterprise-aws.git"
}

variable "common_tags" {
  description = "Tags adicionales aplicados a todos los recursos"
  type        = map(string)
  default = {
    Project     = "aws-3tier-enterprise"
    Environment = "prod"
    ManagedBy   = "terraform"
  }
}
