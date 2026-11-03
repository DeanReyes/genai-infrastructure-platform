output "repository_url" {
  description = "URL del repositorio, usada en docker push y docker pull"
  value       = aws_ecr_repository.this.repository_url
}

output "repository_arn" {
  description = "ARN del repositorio, para escribir politicas de IAM"
  value       = aws_ecr_repository.this.arn
}

output "repository_name" {
  description = "Nombre del repositorio"
  value       = aws_ecr_repository.this.name
}
