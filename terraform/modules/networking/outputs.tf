################################################################################
# terraform/modules/networking/outputs.tf
################################################################################

output "vpc_id" {
  description = "ID de la VPC principal"
  value       = aws_vpc.aws_3tier_vpc.id
}

output "vpc_cidr" {
  description = "CIDR block de la VPC"
  value       = aws_vpc.aws_3tier_vpc.cidr_block
}

# --- Subredes públicas --------------------------------------------------------
output "public_subnet_az1_id" {
  description = "ID subred pública AZ1 (ALB público + NAT Instance)"
  value       = aws_subnet.aws_3tier_public_az1.id
}

output "public_subnet_az2_id" {
  description = "ID subred pública AZ2 (ALB público — requisito AWS)"
  value       = aws_subnet.aws_3tier_public_az2.id
}

# --- Subredes Website ---------------------------------------------------------
output "website_subnet_az1_id" {
  description = "ID subred privada Website AZ1"
  value       = aws_subnet.aws_3tier_website_az1.id
}

output "website_subnet_az2_id" {
  description = "ID subred privada Website AZ2"
  value       = aws_subnet.aws_3tier_website_az2.id
}

# --- Subredes Backend ---------------------------------------------------------
output "backend_subnet_az1_id" {
  description = "ID subred privada Backend AZ1"
  value       = aws_subnet.aws_3tier_backend_az1.id
}

output "backend_subnet_az2_id" {
  description = "ID subred privada Backend AZ2"
  value       = aws_subnet.aws_3tier_backend_az2.id
}

# --- Subredes DB --------------------------------------------------------------
output "db_subnet_az1_id" {
  description = "ID subred DB AZ1 (RDS primary)"
  value       = aws_subnet.aws_3tier_db_az1.id
}

output "db_subnet_az2_id" {
  description = "ID subred DB AZ2 (failover subnet)"
  value       = aws_subnet.aws_3tier_db_az2.id
}

# --- Security Groups ----------------------------------------------------------
output "sg_alb_public_id" {
  description = "ID SG ALB público (sg_alb_public)"
  value       = aws_security_group.aws_3tier_sg_alb_public.id
}

output "sg_website_id" {
  description = "ID SG EC2 Website (sg_website)"
  value       = aws_security_group.aws_3tier_sg_website.id
}

output "sg_alb_internal_id" {
  description = "ID SG ALB interno (sg_alb_internal)"
  value       = aws_security_group.aws_3tier_sg_alb_internal.id
}

output "sg_backend_id" {
  description = "ID SG EC2 Backend (sg_backend)"
  value       = aws_security_group.aws_3tier_sg_backend.id
}

output "sg_database_id" {
  description = "ID SG RDS MySQL (sg_database)"
  value       = aws_security_group.aws_3tier_sg_database.id
}

# --- NAT Instance -------------------------------------------------------------
output "nat_instance_id" {
  description = "ID instancia NAT"
  value       = aws_instance.aws_3tier_nat_instance.id
}

output "nat_instance_public_ip" {
  description = "IP pública de la NAT Instance"
  value       = aws_instance.aws_3tier_nat_instance.public_ip
}

output "private_route_table_id" {
  description = "ID tabla de rutas privada (apunta a NAT Instance ENI)"
  value       = aws_route_table.aws_3tier_private_rt.id
}
