################################################################################
# terraform/modules/networking/main.tf
#
# VPC — 8 subredes (2 pub + 2 website + 2 backend + 2 db)
#
# 6 Security Groups — flujo estricto capa a capa:
#
#   Internet
#       │ 80/443
#   [sg_alb_public]   ALB público
#       │ 80
#   [sg_website]      EC2 Website AZ1 + AZ2
#       │ 3001
#   [sg_alb_internal] ALB interno
#       │ 3001
#   [sg_backend]      EC2 Backend AZ1 + AZ2
#       │ 3306
#   [sg_database]     RDS MySQL
#
# Nadie puede saltarse una capa — cada SG solo acepta del SG anterior.
################################################################################

# ------------------------------------------------------------------------------
# VPC
# ------------------------------------------------------------------------------
resource "aws_vpc" "aws_3tier_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-vpc"
  })
}

# ------------------------------------------------------------------------------
# Internet Gateway
# ------------------------------------------------------------------------------
resource "aws_internet_gateway" "aws_3tier_igw" {
  vpc_id = aws_vpc.aws_3tier_vpc.id

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-igw"
  })
}

# ==============================================================================
# SUBREDES PÚBLICAS — ALB público + NAT Instance
# AWS exige mínimo 2 AZs para un ALB
# ==============================================================================

resource "aws_subnet" "aws_3tier_public_az1" {
  vpc_id                  = aws_vpc.aws_3tier_vpc.id
  cidr_block              = var.public_subnet_az1_cidr # 10.0.1.0/24
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-public-az1"
    Tier = "public"
  })
}

resource "aws_subnet" "aws_3tier_public_az2" {
  vpc_id                  = aws_vpc.aws_3tier_vpc.id
  cidr_block              = var.public_subnet_az2_cidr # 10.0.2.0/24
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-public-az2"
    Tier = "public"
  })
}

# ==============================================================================
# SUBREDES PRIVADAS — capa Website (Nginx + React build)
# ==============================================================================

resource "aws_subnet" "aws_3tier_website_az1" {
  vpc_id            = aws_vpc.aws_3tier_vpc.id
  cidr_block        = var.website_subnet_az1_cidr # 10.0.11.0/24
  availability_zone = "${var.aws_region}a"

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-website-az1"
    Tier = "website"
  })
}

resource "aws_subnet" "aws_3tier_website_az2" {
  vpc_id            = aws_vpc.aws_3tier_vpc.id
  cidr_block        = var.website_subnet_az2_cidr # 10.0.12.0/24
  availability_zone = "${var.aws_region}b"

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-website-az2"
    Tier = "website"
  })
}

# ==============================================================================
# SUBREDES PRIVADAS — capa Backend (Node.js API)
# ==============================================================================

resource "aws_subnet" "aws_3tier_backend_az1" {
  vpc_id            = aws_vpc.aws_3tier_vpc.id
  cidr_block        = var.backend_subnet_az1_cidr # 10.0.21.0/24
  availability_zone = "${var.aws_region}a"

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-backend-az1"
    Tier = "backend"
  })
}

resource "aws_subnet" "aws_3tier_backend_az2" {
  vpc_id            = aws_vpc.aws_3tier_vpc.id
  cidr_block        = var.backend_subnet_az2_cidr # 10.0.22.0/24
  availability_zone = "${var.aws_region}b"

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-backend-az2"
    Tier = "backend"
  })
}

# ==============================================================================
# SUBREDES DB
# AZ1: RDS Primary | AZ2: Failover subnet (requisito AWS DB subnet group)
# Multi-AZ = false en free tier — sin sync replication activa
# ==============================================================================

resource "aws_subnet" "aws_3tier_db_az1" {
  vpc_id            = aws_vpc.aws_3tier_vpc.id
  cidr_block        = var.db_subnet_az1_cidr # 10.0.31.0/24
  availability_zone = "${var.aws_region}a"

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-db-az1"
    Tier = "database"
  })
}

resource "aws_subnet" "aws_3tier_db_az2" {
  vpc_id            = aws_vpc.aws_3tier_vpc.id
  cidr_block        = var.db_subnet_az2_cidr # 10.0.32.0/24
  availability_zone = "${var.aws_region}b"

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-db-az2"
    Tier = "database"
  })
}

# ==============================================================================
# TABLAS DE RUTAS
# ==============================================================================

# Pública → IGW
resource "aws_route_table" "aws_3tier_public_rt" {
  vpc_id = aws_vpc.aws_3tier_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.aws_3tier_igw.id
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-public-rt"
  })
}

resource "aws_route_table_association" "aws_3tier_public_az1" {
  subnet_id      = aws_subnet.aws_3tier_public_az1.id
  route_table_id = aws_route_table.aws_3tier_public_rt.id
}

resource "aws_route_table_association" "aws_3tier_public_az2" {
  subnet_id      = aws_subnet.aws_3tier_public_az2.id
  route_table_id = aws_route_table.aws_3tier_public_rt.id
}

# ------------------------------------------------------------------------------
# SG NAT Instance — permite tráfico 80/443 desde subredes privadas
# ------------------------------------------------------------------------------
resource "aws_security_group" "aws_3tier_sg_nat" {
  name        = "${var.project_name}-sg-nat"
  description = "NAT Instance: reenvio trafico HTTP/HTTPS de subredes privadas"
  vpc_id      = aws_vpc.aws_3tier_vpc.id

  ingress {
    description = "HTTP desde subredes privadas"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [
      var.website_subnet_az1_cidr,
      var.website_subnet_az2_cidr,
      var.backend_subnet_az1_cidr,
      var.backend_subnet_az2_cidr,
    ]
  }

  ingress {
    description = "HTTPS desde subredes privadas"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [
      var.website_subnet_az1_cidr,
      var.website_subnet_az2_cidr,
      var.backend_subnet_az1_cidr,
      var.backend_subnet_az2_cidr,
    ]
  }

  egress {
    description = "Salida irrestricta hacia Internet"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-sg-nat"
  })
}

# AMI Amazon Linux 2 para NAT Instance (iptables MASQUERADE nativo)
data "aws_ami" "amazon_linux_2_nat" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# IAM para SSM en la NAT Instance
resource "aws_iam_role" "aws_3tier_nat_role" {
  name = "${var.project_name}-nat-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "aws_3tier_nat_ssm" {
  role       = aws_iam_role.aws_3tier_nat_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "aws_3tier_nat_profile" {
  name = "${var.project_name}-nat-profile"
  role = aws_iam_role.aws_3tier_nat_role.name
}

# ------------------------------------------------------------------------------
# NAT Instance — Amazon Linux 2, t3.micro, subred pública AZ1
# ------------------------------------------------------------------------------
resource "aws_instance" "aws_3tier_nat_instance" {
  ami                    = data.aws_ami.amazon_linux_2_nat.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.aws_3tier_public_az1.id
  vpc_security_group_ids = [aws_security_group.aws_3tier_sg_nat.id]
  iam_instance_profile   = aws_iam_instance_profile.aws_3tier_nat_profile.name

  # source_dest_check = false:
  #   AWS descarta paquetes cuyo destino no coincide con la IP
  #   de la instancia. Deshabilitarlo la convierte en router:
  #   puede reenviar paquetes ajenos (ej: 10.0.11.5 -> 8.8.8.8).
  #   Sin esto el trafico de EC2 privadas llega a la NAT
  #   pero es descartado inmediatamente.
  source_dest_check = false

  user_data = <<-EOF
    #!/bin/bash
    echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
    sysctl -p
    yum install -y iptables-services
    iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
    service iptables save
    systemctl enable iptables
    systemctl start iptables
  EOF

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-nat-instance"
    Role = "nat"
  })
}

# ------------------------------------------------------------------------------
# Tabla de rutas privada (Website + Backend) → NAT Instance ENI
#
# Ruta 0.0.0.0/0 → ENI de la NAT:
#   La tabla privada dirige todo trafico sin destino local hacia la ENI
#   de la NAT. Esta hace SNAT con su IP publica. npm install, git pull
#   y SSM Agent funcionan desde EC2 sin IP publica gracias a este mecanismo.
# ------------------------------------------------------------------------------
resource "aws_route_table" "aws_3tier_private_rt" {
  vpc_id = aws_vpc.aws_3tier_vpc.id

  route {
    cidr_block           = "0.0.0.0/0"
    network_interface_id = aws_instance.aws_3tier_nat_instance.primary_network_interface_id
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-private-rt"
  })
}

resource "aws_route_table_association" "aws_3tier_website_az1" {
  subnet_id      = aws_subnet.aws_3tier_website_az1.id
  route_table_id = aws_route_table.aws_3tier_private_rt.id
}

resource "aws_route_table_association" "aws_3tier_website_az2" {
  subnet_id      = aws_subnet.aws_3tier_website_az2.id
  route_table_id = aws_route_table.aws_3tier_private_rt.id
}

resource "aws_route_table_association" "aws_3tier_backend_az1" {
  subnet_id      = aws_subnet.aws_3tier_backend_az1.id
  route_table_id = aws_route_table.aws_3tier_private_rt.id
}

resource "aws_route_table_association" "aws_3tier_backend_az2" {
  subnet_id      = aws_subnet.aws_3tier_backend_az2.id
  route_table_id = aws_route_table.aws_3tier_private_rt.id
}

# DB — sin salida a internet (aislamiento total)
resource "aws_route_table" "aws_3tier_db_rt" {
  vpc_id = aws_vpc.aws_3tier_vpc.id

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-db-rt"
  })
}

resource "aws_route_table_association" "aws_3tier_db_az1" {
  subnet_id      = aws_subnet.aws_3tier_db_az1.id
  route_table_id = aws_route_table.aws_3tier_db_rt.id
}

resource "aws_route_table_association" "aws_3tier_db_az2" {
  subnet_id      = aws_subnet.aws_3tier_db_az2.id
  route_table_id = aws_route_table.aws_3tier_db_rt.id
}

# ==============================================================================
# SECURITY GROUPS — 6 SGs, flujo estricto capa a capa
# Nadie puede saltarse una capa.
# ==============================================================================

# ------------------------------------------------------------------------------
# SG 1: sg_alb_public — ALB público
# ingress: 80 y 443 desde 0.0.0.0/0
# egress:  80 hacia sg_website
# ------------------------------------------------------------------------------
resource "aws_security_group" "aws_3tier_sg_alb_public" {
  name        = "${var.project_name}-sg-alb-public"
  description = "ALB publico: acepta HTTP/HTTPS de Internet, reenvia a Website"
  vpc_id      = aws_vpc.aws_3tier_vpc.id

  ingress {
    description = "HTTP desde Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS desde Internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description     = "Hacia EC2 Website puerto 80"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.aws_3tier_sg_website.id]
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-sg-alb-public"
  })
}

# ------------------------------------------------------------------------------
# SG 2: sg_website — EC2 Website (Nginx + React/Vite build)
# ingress: 80 solo desde sg_alb_public
# egress:  3001 hacia sg_alb_internal
#          443 hacia 0.0.0.0/0 (SSM Agent + git pull via NAT)
# ------------------------------------------------------------------------------
resource "aws_security_group" "aws_3tier_sg_website" {
  name        = "${var.project_name}-sg-website"
  description = "EC2 Website: acepta desde ALB publico, envia a ALB interno y NAT"
  vpc_id      = aws_vpc.aws_3tier_vpc.id

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-sg-website"
  })
}

resource "aws_security_group_rule" "aws_3tier_website_ingress_alb_public" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  security_group_id        = aws_security_group.aws_3tier_sg_website.id
  source_security_group_id = aws_security_group.aws_3tier_sg_alb_public.id
  description              = "HTTP solo desde ALB publico"
}

resource "aws_security_group_rule" "aws_3tier_website_egress_alb_internal" {
  type                     = "egress"
  from_port                = 3001
  to_port                  = 3001
  protocol                 = "tcp"
  security_group_id        = aws_security_group.aws_3tier_sg_website.id
  source_security_group_id = aws_security_group.aws_3tier_sg_alb_internal.id
  description              = "Hacia ALB interno puerto 3001"
}

resource "aws_security_group_rule" "aws_3tier_website_egress_https_nat" {
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.aws_3tier_sg_website.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "HTTPS hacia Internet via NAT (SSM Agent, git pull)"
}

# ------------------------------------------------------------------------------
# SG 3: sg_alb_internal — ALB interno (entre Website y Backend)
# ingress: 3001 solo desde sg_website
# egress:  3001 hacia sg_backend
# ------------------------------------------------------------------------------
resource "aws_security_group" "aws_3tier_sg_alb_internal" {
  name        = "${var.project_name}-sg-alb-internal"
  description = "ALB interno: acepta de Website, reenvia a Backend en puerto 3001"
  vpc_id      = aws_vpc.aws_3tier_vpc.id

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-sg-alb-internal"
  })
}

resource "aws_security_group_rule" "aws_3tier_alb_internal_ingress_website" {
  type                     = "ingress"
  from_port                = 3001
  to_port                  = 3001
  protocol                 = "tcp"
  security_group_id        = aws_security_group.aws_3tier_sg_alb_internal.id
  source_security_group_id = aws_security_group.aws_3tier_sg_website.id
  description              = "API puerto 3001 solo desde sg_website"
}

resource "aws_security_group_rule" "aws_3tier_alb_internal_egress_backend" {
  type                     = "egress"
  from_port                = 3001
  to_port                  = 3001
  protocol                 = "tcp"
  security_group_id        = aws_security_group.aws_3tier_sg_alb_internal.id
  source_security_group_id = aws_security_group.aws_3tier_sg_backend.id
  description              = "Hacia EC2 Backend puerto 3001"
}

# ------------------------------------------------------------------------------
# SG 4: sg_backend — EC2 Backend (Node.js API)
# ingress: 3001 solo desde sg_alb_internal
# egress:  3306 hacia sg_database
#          443 hacia 0.0.0.0/0 (SSM Agent + npm install via NAT)
# ------------------------------------------------------------------------------
resource "aws_security_group" "aws_3tier_sg_backend" {
  name        = "${var.project_name}-sg-backend"
  description = "EC2 Backend: acepta solo de ALB interno, envia a DB y NAT"
  vpc_id      = aws_vpc.aws_3tier_vpc.id

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-sg-backend"
  })
}

resource "aws_security_group_rule" "aws_3tier_backend_ingress_alb_internal" {
  type                     = "ingress"
  from_port                = 3001
  to_port                  = 3001
  protocol                 = "tcp"
  security_group_id        = aws_security_group.aws_3tier_sg_backend.id
  source_security_group_id = aws_security_group.aws_3tier_sg_alb_internal.id
  description              = "API puerto 3001 solo desde ALB interno"
}

resource "aws_security_group_rule" "aws_3tier_backend_egress_db" {
  type                     = "egress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  security_group_id        = aws_security_group.aws_3tier_sg_backend.id
  source_security_group_id = aws_security_group.aws_3tier_sg_database.id
  description              = "MySQL hacia RDS puerto 3306"
}

resource "aws_security_group_rule" "aws_3tier_backend_egress_https_nat" {
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.aws_3tier_sg_backend.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "HTTPS hacia Internet via NAT (SSM Agent, npm install)"
}

# ------------------------------------------------------------------------------
# SG 5: sg_database — RDS MySQL
# ingress: 3306 solo desde sg_backend
# egress:  ninguno
# ------------------------------------------------------------------------------
resource "aws_security_group" "aws_3tier_sg_database" {
  name        = "${var.project_name}-sg-database"
  description = "RDS MySQL: acepta solo desde Backend, sin salida"
  vpc_id      = aws_vpc.aws_3tier_vpc.id

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-sg-database"
  })
}

resource "aws_security_group_rule" "aws_3tier_database_ingress_backend" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  security_group_id        = aws_security_group.aws_3tier_sg_database.id
  source_security_group_id = aws_security_group.aws_3tier_sg_backend.id
  description              = "MySQL puerto 3306 solo desde sg_backend"
}
