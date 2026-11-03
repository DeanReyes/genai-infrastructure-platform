terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0, < 7.0"
    }
  }
}

provider "aws" {
  region = var.region
}

locals {
  tags = {
    Environment = "dev"
    ManagedBy   = "genai-infrastructure-platform"
  }
}

module "ecr" {
  source = "../../modules/ecr"

  repository_name  = "${var.app_name}/api"
  keep_last_images = 10
  force_delete     = true # solo para el entorno de pruebas del curso
  tags             = local.tags
}

module "secrets_manager" {
  source = "../../modules/secrets-manager"

  secret_name             = "${var.app_name}/dev/db-password"
  secret_description      = "Contrasena de base de datos de ${var.app_name} (entorno dev)"
  recovery_window_in_days = 7
  tags                    = local.tags
}
