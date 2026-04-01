################################################################################
# terraform/environments/prod/main.tf
# Composicion de modulos + recursos globales (IAM OIDC)
################################################################################

# ------------------------------------------------------------------------------
# IAM OIDC Provider — autenticacion sin credenciales para GitHub Actions
# El token JWT de GitHub es validado directamente contra AWS STS
# ------------------------------------------------------------------------------
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]

  # Thumbprint del certificado raiz de token.actions.githubusercontent.com
  # Valor estatico definido por GitHub — actualizar si GitHub rota su cert
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-github-oidc"
  })
}

# ------------------------------------------------------------------------------
# IAM Role — asumido por GitHub Actions via OIDC (sin access keys)
# ------------------------------------------------------------------------------
resource "aws_iam_role" "github_actions" {
  name        = "aws-3tier-github-actions-role"
  description = "Rol para GitHub Actions via OIDC — sin credenciales estaticas"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:carlossanchezcloud/3tier-enterprise-aws:*"
        }
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = var.common_tags
}

# Politica least privilege para infra.yml y app.yml
resource "aws_iam_role_policy" "github_actions_policy" {
  name = "aws-3tier-github-actions-policy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "TerraformStateAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::aws-3tier-app-saloncitas-tfstate",
          "arn:aws:s3:::aws-3tier-app-saloncitas-tfstate/*"
        ]
      },
      {
        Sid    = "InfraDescribe"
        Effect = "Allow"
        Action = [
          "ec2:Describe*",
          "elasticloadbalancing:Describe*",
          "autoscaling:Describe*",
          "rds:Describe*",
          "iam:GetRole",
          "iam:GetOpenIDConnectProvider",
          "iam:ListRolePolicies",
          "iam:GetRolePolicy"
        ]
        Resource = "*"
      },
      {
        Sid    = "AppDeploySSM"
        Effect = "Allow"
        Action = [
          "ssm:SendCommand",
          "ssm:GetCommandInvocation",
          "ssm:ListCommandInvocations"
        ]
        Resource = "*"
      },
      {
        Sid    = "AppDeployDescribe"
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "tag:GetResources"
        ]
        Resource = "*"
      }
    ]
  })
}

# ------------------------------------------------------------------------------
# Modulo networking
# ------------------------------------------------------------------------------
module "networking" {
  source = "../../modules/networking"

  project_name            = var.project_name
  aws_region              = var.aws_region
  vpc_cidr                = var.vpc_cidr
  public_subnet_az1_cidr  = var.public_subnet_az1_cidr
  public_subnet_az2_cidr  = var.public_subnet_az2_cidr
  website_subnet_az1_cidr = var.website_subnet_az1_cidr
  website_subnet_az2_cidr = var.website_subnet_az2_cidr
  backend_subnet_az1_cidr = var.backend_subnet_az1_cidr
  backend_subnet_az2_cidr = var.backend_subnet_az2_cidr
  db_subnet_az1_cidr      = var.db_subnet_az1_cidr
  db_subnet_az2_cidr      = var.db_subnet_az2_cidr
  common_tags             = var.common_tags
}

# ------------------------------------------------------------------------------
# Modulo database
# ------------------------------------------------------------------------------
module "database" {
  source = "../../modules/database"

  project_name   = var.project_name
  db_name        = var.db_name
  db_user        = var.db_user
  db_password    = var.db_password
  db_subnet_ids  = [module.networking.db_subnet_az1_id, module.networking.db_subnet_az2_id]
  sg_database_id = module.networking.sg_database_id
  common_tags    = var.common_tags
}

# ------------------------------------------------------------------------------
# Modulo compute
# ------------------------------------------------------------------------------
module "compute" {
  source = "../../modules/compute"

  project_name       = var.project_name
  aws_region         = var.aws_region
  vpc_id             = module.networking.vpc_id
  public_subnet_ids  = [module.networking.public_subnet_az1_id, module.networking.public_subnet_az2_id]
  website_subnet_ids = [module.networking.website_subnet_az1_id, module.networking.website_subnet_az2_id]
  backend_subnet_ids = [module.networking.backend_subnet_az1_id, module.networking.backend_subnet_az2_id]
  sg_alb_public_id   = module.networking.sg_alb_public_id
  sg_alb_internal_id = module.networking.sg_alb_internal_id
  sg_website_id      = module.networking.sg_website_id
  sg_backend_id      = module.networking.sg_backend_id
  rds_endpoint       = module.database.rds_endpoint
  db_name            = var.db_name
  db_user            = var.db_user
  db_password        = var.db_password
  repo_url           = var.repo_url
  common_tags        = var.common_tags
}
