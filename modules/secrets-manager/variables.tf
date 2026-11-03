variable "secret_name" {
  type        = string
  description = "Nombre del secreto, por ejemplo pagos/dev/db-password. Admite letras, numeros y los caracteres / _ + = . @ -"

  validation {
    condition     = can(regex("^[A-Za-z0-9/_+=.@-]{1,512}$", var.secret_name))
    error_message = "secret_name admite de 1 a 512 caracteres: letras, numeros y / _ + = . @ -"
  }
}

variable "secret_description" {
  type        = string
  description = "Descripcion del secreto: que credencial guarda y que aplicacion la usa"
  default     = "Secreto gestionado por Terraform"
}

variable "recovery_window_in_days" {
  type        = number
  description = "Dias que el secreto queda recuperable tras borrarlo (7 a 30); 0 lo elimina de inmediato"
  default     = 7

  validation {
    condition     = var.recovery_window_in_days == 0 || (var.recovery_window_in_days >= 7 && var.recovery_window_in_days <= 30)
    error_message = "recovery_window_in_days debe ser 0 o estar entre 7 y 30."
  }
}

variable "kms_key_id" {
  type        = string
  description = "ARN o alias de una clave KMS propia para cifrar el secreto; si es null se usa la clave gestionada por AWS"
  default     = null
}

variable "tags" {
  type        = map(string)
  description = "Etiquetas que se aplican al secreto"
  default     = {}
}
