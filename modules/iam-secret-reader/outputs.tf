output "role_arn" {
  description = "ARN del rol, para asumirlo con sts assume-role o asignarlo a la aplicacion"
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "Nombre del rol"
  value       = aws_iam_role.this.name
}
