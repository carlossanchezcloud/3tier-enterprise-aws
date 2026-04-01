################################################################################
# terraform/modules/compute/main.tf
#
# Flujo de tráfico:
#   Internet → ALB público (sg_alb_public)
#            → ASG Website en website_subnets (sg_website)
#            → ALB interno (sg_alb_internal) en website_subnets
#            → ASG Backend en backend_subnets (sg_backend)
#            → RDS (sg_database)
################################################################################

# ------------------------------------------------------------------------------
# AMI — Amazon Linux 2023 más reciente (us-east-1)
# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
# AMI — Amazon Linux 2023 más reciente via SSM Parameter Store
# ------------------------------------------------------------------------------
data "aws_ssm_parameter" "amazon_linux_2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# ==============================================================================
# IAM — SSM sin SSH (instancias inaccesibles por red directa)
# ==============================================================================

resource "aws_iam_role" "aws_3tier_ec2_role" {
  name        = "${var.project_name}-ec2-role"
  description = "Rol EC2: acceso SSM sin credenciales estaticas ni SSH"

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

resource "aws_iam_role_policy_attachment" "aws_3tier_ssm_core" {
  role       = aws_iam_role.aws_3tier_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "aws_3tier_ec2_profile" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.aws_3tier_ec2_role.name
}

# ==============================================================================
# ALB PÚBLICO — internet-facing, subredes públicas AZ1 + AZ2
# SG: sg_alb_public
# ==============================================================================

resource "aws_lb" "aws_3tier_public_alb" {
  name               = "${replace(var.project_name, "_", "-")}-public-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.sg_alb_public_id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = false

  tags = merge(var.common_tags, {
    Name   = "${var.project_name}-public-alb"
    Scheme = "internet-facing"
  })
}

resource "aws_lb_target_group" "aws_3tier_website_tg" {
  name     = "${replace(var.project_name, "_", "-")}-website-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/health"
    protocol            = "HTTP"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
    timeout             = 5
    matcher             = "200"
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-website-tg"
  })
}

resource "aws_lb_listener" "aws_3tier_public_http" {
  load_balancer_arn = aws_lb.aws_3tier_public_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.aws_3tier_website_tg.arn
  }
}

# ==============================================================================
# ALB INTERNO — entre capa Website y capa Backend
# SG: sg_alb_internal — solo acepta de sg_website, solo envía a sg_backend
# Desplegado en subredes Website (accesible desde EC2 Website)
# ==============================================================================

resource "aws_lb" "aws_3tier_internal_alb" {
  name               = "${replace(var.project_name, "_", "-")}-internal-alb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [var.sg_alb_internal_id]
  subnets            = var.website_subnet_ids

  enable_deletion_protection = false

  tags = merge(var.common_tags, {
    Name   = "${var.project_name}-internal-alb"
    Scheme = "internal"
  })
}

resource "aws_lb_target_group" "aws_3tier_backend_tg" {
  name     = "${replace(var.project_name, "_", "-")}-backend-tg"
  port     = 3001
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/health"
    protocol            = "HTTP"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
    timeout             = 5
    matcher             = "200"
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-backend-tg"
  })
}

resource "aws_lb_listener" "aws_3tier_internal_api" {
  load_balancer_arn = aws_lb.aws_3tier_internal_alb.arn
  port              = 3001
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.aws_3tier_backend_tg.arn
  }
}

# ==============================================================================
# ASG WEBSITE — subredes website_az1 + website_az2
# SG: sg_website | t3.micro | min=2 max=4 desired=2 | EBS 30GB gp3
# ==============================================================================

resource "aws_launch_template" "aws_3tier_website_lt" {
  name_prefix   = "${var.project_name}-website-lt-"
  description   = "Launch template EC2 Website — Nginx + React/Vite build"
  image_id      = data.aws_ssm_parameter.amazon_linux_2023.value
  instance_type = "t3.micro"

  iam_instance_profile {
    name = aws_iam_instance_profile.aws_3tier_ec2_profile.name
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [var.sg_website_id]
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 30
      volume_type           = "gp3"
      delete_on_termination = true
      encrypted             = true
    }
  }

  user_data = base64encode(templatefile("${path.root}/../../../scripts/user_data_website.sh", {
    repo_url    = var.repo_url
    backend_alb = aws_lb.aws_3tier_internal_alb.dns_name
    cors_origin = aws_lb.aws_3tier_public_alb.dns_name
  }))

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.common_tags, {
      Name = "${var.project_name}-website"
      Role = "website"
    })
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "aws_3tier_website_asg" {
  name                = "${var.project_name}-website-asg"
  vpc_zone_identifier = var.website_subnet_ids
  min_size            = 2
  max_size            = 4
  desired_capacity    = 2

  launch_template {
    id      = aws_launch_template.aws_3tier_website_lt.id
    version = "$Latest"
  }

  target_group_arns         = [aws_lb_target_group.aws_3tier_website_tg.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 120

  tag {
    key                 = "Name"
    value               = "${var.project_name}-website"
    propagate_at_launch = true
  }

  tag {
    key                 = "ASG"
    value               = "${var.project_name}-website-asg"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ==============================================================================
# ASG BACKEND — subredes backend_az1 + backend_az2
# SG: sg_backend | t3.micro | min=2 max=4 desired=2 | EBS 30GB gp3
# ==============================================================================

resource "aws_launch_template" "aws_3tier_backend_lt" {
  name_prefix   = "${var.project_name}-backend-lt-"
  description   = "Launch template EC2 Backend — Node.js API + PM2"
  image_id      = data.aws_ssm_parameter.amazon_linux_2023.value
  instance_type = "t3.micro"

  iam_instance_profile {
    name = aws_iam_instance_profile.aws_3tier_ec2_profile.name
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [var.sg_backend_id]
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 30
      volume_type           = "gp3"
      delete_on_termination = true
      encrypted             = true
    }
  }

  user_data = base64encode(templatefile("${path.root}/../../../scripts/user_data_backend.sh", {
    repo_url    = var.repo_url
    db_host     = split(":", var.rds_endpoint)[0]
    db_port     = "3306"
    db_name     = var.db_name
    db_user     = var.db_user
    db_password = var.db_password
    cors_origin = aws_lb.aws_3tier_public_alb.dns_name
    node_env    = "production"
  }))

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.common_tags, {
      Name = "${var.project_name}-backend"
      Role = "backend"
    })
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "aws_3tier_backend_asg" {
  name                = "${var.project_name}-backend-asg"
  vpc_zone_identifier = var.backend_subnet_ids
  min_size            = 2
  max_size            = 4
  desired_capacity    = 2

  launch_template {
    id      = aws_launch_template.aws_3tier_backend_lt.id
    version = "$Latest"
  }

  target_group_arns         = [aws_lb_target_group.aws_3tier_backend_tg.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 180

  tag {
    key                 = "Name"
    value               = "${var.project_name}-backend"
    propagate_at_launch = true
  }

  tag {
    key                 = "ASG"
    value               = "${var.project_name}-backend-asg"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}
