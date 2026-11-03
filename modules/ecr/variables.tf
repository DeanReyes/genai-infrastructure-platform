variable "repository_name" {
  type        = string
  description = "Nombre del repositorio ECR para las imagenes Docker de la aplicacion, por ejemplo pagos/api. Solo minusculas, numeros y - _ . /"

  validation {
    condition     = can(regex("^[a-z0-9]+(?:[._/-][a-z0-9]+)*$", var.repository_name))
    error_message = "repository_name solo admite minusculas, numeros y los separadores . _ - /"
  }
}

variable "image_tag_mutability" {
  type        = string
  description = "IMMUTABLE impide sobrescribir una etiqueta ya publicada (recomendado); MUTABLE lo permite"
  default     = "IMMUTABLE"

  validation {
    condition     = contains(["IMMUTABLE", "MUTABLE"], var.image_tag_mutability)
    error_message = "image_tag_mutability debe ser IMMUTABLE o MUTABLE."
  }
}

variable "scan_on_push" {
  type        = bool
  description = "Escanea cada imagen en busca de vulnerabilidades al subirla"
  default     = true
}

variable "keep_last_images" {
  type        = number
  description = "Numero de imagenes mas recientes que se conservan; las anteriores se eliminan automaticamente"
  default     = 20

  validation {
    condition     = var.keep_last_images >= 1 && var.keep_last_images <= 1000
    error_message = "keep_last_images debe estar entre 1 y 1000."
  }
}

variable "kms_key_arn" {
  type        = string
  description = "ARN de una clave KMS para cifrar las imagenes; si es null se usa el cifrado gestionado por AES256"
  default     = null
}

variable "force_delete" {
  type        = bool
  description = "Permite borrar el repositorio aunque contenga imagenes (util en entornos de prueba)"
  default     = false
}

variable "tags" {
  type        = map(string)
  description = "Etiquetas que se aplican al repositorio"
  default     = {}
}
