################################################################################
# terraform/environments/prod/outputs.tf
################################################################################

output "public_alb_dns" {
  description = "DNS del ALB publico — URL de acceso a la aplicacion"
  value       = module.compute.public_alb_dns
}

output "internal_alb_dns" {
  description = "DNS del ALB interno — Nginx hace proxy hacia este endpoint"
  value       = module.compute.internal_alb_dns
}

output "rds_endpoint" {
  description = "Endpoint RDS MySQL (host:port)"
  value       = module.database.rds_endpoint
  sensitive   = true
}

output "rds_host" {
  description = "Hostname RDS (sin puerto)"
  value       = module.database.rds_host
  sensitive   = true
}

output "vpc_id" {
  description = "ID VPC principal"
  value       = module.networking.vpc_id
}

output "public_subnet_az1_id" {
  description = "ID subred publica AZ1"
  value       = module.networking.public_subnet_az1_id
}

output "public_subnet_az2_id" {
  description = "ID subred publica AZ2"
  value       = module.networking.public_subnet_az2_id
}

output "website_subnet_az1_id" {
  description = "ID subred privada Website AZ1"
  value       = module.networking.website_subnet_az1_id
}

output "website_subnet_az2_id" {
  description = "ID subred privada Website AZ2"
  value       = module.networking.website_subnet_az2_id
}

output "backend_subnet_az1_id" {
  description = "ID subred privada Backend AZ1"
  value       = module.networking.backend_subnet_az1_id
}

output "backend_subnet_az2_id" {
  description = "ID subred privada Backend AZ2"
  value       = module.networking.backend_subnet_az2_id
}

output "db_subnet_az1_id" {
  description = "ID subred DB AZ1"
  value       = module.networking.db_subnet_az1_id
}

output "db_subnet_az2_id" {
  description = "ID subred DB AZ2"
  value       = module.networking.db_subnet_az2_id
}

output "website_asg_name" {
  description = "Nombre ASG Website — usado por app.yml para SSM Send Command"
  value       = module.compute.website_asg_name
}

output "backend_asg_name" {
  description = "Nombre ASG Backend — usado por app.yml para SSM Send Command"
  value       = module.compute.backend_asg_name
}

output "nat_instance_id" {
  description = "ID instancia NAT"
  value       = module.networking.nat_instance_id
}

output "github_actions_role_arn" {
  description = "ARN IAM Role GitHub Actions (OIDC)"
  value       = aws_iam_role.github_actions.arn
}
