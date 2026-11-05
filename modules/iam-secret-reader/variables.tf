variable "role_name" {
  type        = string
  description = "Nombre del rol IAM que podra leer los secretos, por ejemplo pagos-dev-secret-reader. Admite letras, numeros y los caracteres + = , . @ _ -"

  validation {
    condition     = can(regex("^[A-Za-z0-9+=,.@_-]{1,64}$", var.role_name))
    error_message = "role_name admite de 1 a 64 caracteres: letras, numeros y + = , . @ _ -"
  }
}

variable "secret_arns" {
  type        = list(string)
  description = "ARN de los secretos de Secrets Manager que el rol puede leer. No se admite un comodin total"

  validation {
    condition     = length(var.secret_arns) > 0 && alltrue([for arn in var.secret_arns : can(regex("^arn:aws[a-z-]*:secretsmanager:[a-z0-9-]+:[0-9]{12}:secret:.+$", arn))])
    error_message = "secret_arns debe tener al menos un ARN de Secrets Manager con el formato arn:aws:secretsmanager:region:cuenta:secret:nombre"
  }
}

variable "trusted_principal_arns" {
  type        = list(string)
  description = "ARN de los usuarios o roles IAM que pueden asumir este rol, por ejemplo el rol de la aplicacion"

  validation {
    condition     = length(var.trusted_principal_arns) > 0 && alltrue([for arn in var.trusted_principal_arns : can(regex("^arn:aws[a-z-]*:iam::[0-9]{12}:(root|user/.+|role/.+)$", arn))])
    error_message = "trusted_principal_arns debe tener al menos un ARN de cuenta (root), usuario (user/...) o rol (role/...) de IAM."
  }
}

variable "kms_key_arns" {
  type        = list(string)
  description = "ARN de las claves KMS propias con las que se cifraron los secretos; si estan vacio no se concede kms:Decrypt"
  default     = []
}

variable "max_session_duration" {
  type        = number
  description = "Duracion maxima en segundos de la sesion al asumir el rol (3600 a 43200)"
  default     = 3600

  validation {
    condition     = var.max_session_duration >= 3600 && var.max_session_duration <= 43200
    error_message = "max_session_duration debe estar entre 3600 y 43200 segundos."
  }
}

variable "tags" {
  type        = map(string)
  description = "Etiquetas que se aplican al rol"
  default     = {}
}
