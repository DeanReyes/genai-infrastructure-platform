output "ecr_repository_url" {
  description = "URL del repositorio ECR para docker push/pull"
  value       = module.ecr.repository_url
}

output "secret_arn" {
  description = "ARN del secreto creado"
  value       = module.secrets_manager.secret_arn
}
