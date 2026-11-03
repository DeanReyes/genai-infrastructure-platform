resource "aws_secretsmanager_secret" "this" {
  name                    = var.secret_name
  description             = var.secret_description
  recovery_window_in_days = var.recovery_window_in_days
  kms_key_id              = var.kms_key_id

  tags = var.tags
}

# Valor de marcador: el valor real se carga fuera de Terraform (consola o AWS CLI)
# para que la credencial nunca pase por el codigo, un Issue ni el estado.
resource "aws_secretsmanager_secret_version" "placeholder" {
  secret_id     = aws_secretsmanager_secret.this.id
  secret_string = "CAMBIAR-ESTE-VALOR"

  lifecycle {
    ignore_changes = [secret_string]
  }
}
