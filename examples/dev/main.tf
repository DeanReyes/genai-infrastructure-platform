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

# Para la demostracion, el rol lo puede asumir el mismo usuario que ejecuta Terraform.
# En una aplicacion real se indicaria el rol de la tarea de ECS o del pod de EKS.
data "aws_caller_identity" "current" {}

module "secret_reader" {
  source = "../../modules/iam-secret-reader"

  role_name              = "${var.app_name}-dev-secret-reader"
  secret_arns            = [module.secrets_manager.secret_arn]
  trusted_principal_arns = [data.aws_caller_identity.current.arn]
  tags                   = local.tags
}
