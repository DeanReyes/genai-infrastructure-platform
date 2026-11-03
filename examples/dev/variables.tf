variable "region" {
  type        = string
  description = "Region de AWS donde se despliegan los recursos"
  default     = "us-east-1"
}

variable "app_name" {
  type        = string
  description = "Nombre de la aplicacion, usado como prefijo de los recursos"
  default     = "demo"
}
