output "ecr_repository_url" {
  description = "URL del repositorio ECR para docker push/pull"
  value       = module.ecr.repository_url
}

output "secret_arn" {
  description = "ARN del secreto creado"
  value       = module.secrets_manager.secret_arn
}

output "secret_reader_role_arn" {
  description = "ARN del rol que puede leer el secreto"
  value       = module.secret_reader.role_arn
}
