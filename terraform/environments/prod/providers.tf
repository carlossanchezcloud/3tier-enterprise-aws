################################################################################
# terraform/environments/prod/providers.tf
# Backend S3 + proveedor AWS
################################################################################

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket       = "aws-3tier-app-saloncitas-tfstate"
    key          = "prod/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "aws-3tier-enterprise"
      Environment = "prod"
      ManagedBy   = "terraform"
      Repository  = "carlossanchezcloud/3tier-enterprise-aws"
    }
  }
}
