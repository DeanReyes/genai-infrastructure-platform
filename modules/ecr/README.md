# Módulo ecr

Crea un repositorio de **Amazon ECR** (Elastic Container Registry): el lugar privado de AWS donde se guardan las imágenes Docker de una aplicación.

## Qué función cumple

Un equipo construye imágenes de su aplicación y necesita un registro seguro donde publicarlas y desde donde descargarlas. Este módulo crea ese registro ya configurado con las reglas de seguridad de la plataforma:

- **Escaneo en push:** cada imagen se revisa en busca de vulnerabilidades conocidas al subirla.
- **Tags inmutables:** una etiqueta ya publicada (por ejemplo `v1`) no se puede sobrescribir.
- **Limpieza automática:** solo se conservan las últimas N imágenes; las anteriores se eliminan.
- **Cifrado:** AES256 gestionado por AWS, o una clave KMS propia si se indica.

El módulo solo crea el repositorio. **No sube imágenes**: eso lo hace Docker o el pipeline de CI/CD de la aplicación.

## Qué hace cada archivo

| Archivo | Función |
|---|---|
| [main.tf](main.tf) | Declara los dos recursos: `aws_ecr_repository` (el repositorio, con escaneo, mutabilidad y cifrado) y `aws_ecr_lifecycle_policy` (la regla que conserva las últimas N imágenes). |
| [variables.tf](variables.tf) | Define lo que se puede configurar, con valores por defecto y validaciones. |
| [outputs.tf](outputs.tf) | Define los datos que el módulo devuelve a quien lo usa. |
| [versions.tf](versions.tf) | Fija la versión mínima de Terraform (`>= 1.5.0`) y del provider de AWS (`>= 5.0, < 7.0`). |

## Entradas (variables)

| Variable | Tipo | Por defecto | Descripción |
|---|---|---|---|
| `repository_name` | `string` | — (obligatoria) | Nombre del repositorio, por ejemplo `pagos/api`. Solo minúsculas, números y `. _ - /`. |
| `image_tag_mutability` | `string` | `IMMUTABLE` | `IMMUTABLE` impide sobrescribir etiquetas; `MUTABLE` lo permite. |
| `scan_on_push` | `bool` | `true` | Escanea cada imagen al subirla. |
| `keep_last_images` | `number` | `20` | Imágenes que se conservan (entre 1 y 1000). |
| `kms_key_arn` | `string` | `null` | Clave KMS propia; si es `null` se usa AES256. |
| `force_delete` | `bool` | `false` | Permite borrar el repositorio aunque tenga imágenes. Solo para pruebas. |
| `tags` | `map(string)` | `{}` | Etiquetas que se aplican al repositorio. |

## Resultado que devuelve (outputs)

| Output | Qué contiene | Para qué se usa |
|---|---|---|
| `repository_url` | URL del repositorio | `docker push` y `docker pull` |
| `repository_arn` | ARN del repositorio | Escribir políticas IAM que den acceso al repositorio |
| `repository_name` | Nombre del repositorio | Referenciarlo desde otros recursos |

## Ejemplo de uso

```hcl
module "ecr" {
  source = "../../modules/ecr"

  repository_name  = "pagos/api"
  keep_last_images = 10
  tags             = { Environment = "dev" }
}

output "ecr_url" {
  value = module.ecr.repository_url
}
```

Desde otro repositorio se referencia directamente desde GitHub:

```hcl
source = "git::https://github.com/DeanReyes/genai-infrastructure-platform.git//modules/ecr?ref=main"
```

## Política asociada

[policy/ecr.rego](../../policy/ecr.rego) comprueba sobre el plan de Terraform que el repositorio tenga `scan_on_push` activo y tags `IMMUTABLE`. Sus tests están en [tests/ecr_test.rego](../../tests/ecr_test.rego).

## Cómo se prueba

```bash
terraform init -backend=false
terraform validate
opa test ../../policy ../../tests
```

Para desplegarlo de verdad, usa [examples/dev](../../examples/dev). El usuario de AWS necesita permisos de ECR; en una cuenta de pruebas sirve la política administrada `AmazonEC2ContainerRegistryFullAccess`.
