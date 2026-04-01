################################################################################
# terraform/modules/networking/variables.tf
################################################################################

variable "project_name" {
  description = "Prefijo para nombrar todos los recursos (snake_case)"
  type        = string
  default     = "aws_3tier"
}

variable "aws_region" {
  description = "Region AWS donde se despliegan los recursos"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block de la VPC principal"
  type        = string
  default     = "10.0.0.0/16"
}

# Subredes publicas
variable "public_subnet_az1_cidr" {
  description = "CIDR subred publica AZ1 — ALB publico y NAT Instance"
  type        = string
  default     = "10.0.1.0/24"
}

variable "public_subnet_az2_cidr" {
  description = "CIDR subred publica AZ2 — ALB publico (requisito AWS multi-AZ)"
  type        = string
  default     = "10.0.2.0/24"
}

# Subredes privadas — capa Website
variable "website_subnet_az1_cidr" {
  description = "CIDR subred privada Website AZ1 — EC2 Nginx + React build"
  type        = string
  default     = "10.0.11.0/24"
}

variable "website_subnet_az2_cidr" {
  description = "CIDR subred privada Website AZ2 — EC2 Nginx + React build"
  type        = string
  default     = "10.0.12.0/24"
}

# Subredes privadas — capa Backend
variable "backend_subnet_az1_cidr" {
  description = "CIDR subred privada Backend AZ1 — EC2 Node.js API"
  type        = string
  default     = "10.0.21.0/24"
}

variable "backend_subnet_az2_cidr" {
  description = "CIDR subred privada Backend AZ2 — EC2 Node.js API"
  type        = string
  default     = "10.0.22.0/24"
}

# Subredes DB
variable "db_subnet_az1_cidr" {
  description = "CIDR subred DB AZ1 — RDS primary"
  type        = string
  default     = "10.0.31.0/24"
}

variable "db_subnet_az2_cidr" {
  description = "CIDR subred DB AZ2 — failover subnet (requisito AWS DB subnet group)"
  type        = string
  default     = "10.0.32.0/24"
}

variable "common_tags" {
  description = "Mapa de tags aplicados a todos los recursos"
  type        = map(string)
  default = {
    Project     = "aws-3tier-enterprise"
    Environment = "prod"
    ManagedBy   = "terraform"
  }
}
