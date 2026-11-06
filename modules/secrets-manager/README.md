# Módulo secrets-manager

Crea un **secreto de AWS Secrets Manager**: el lugar cifrado donde una aplicación guarda una credencial (contraseña de base de datos, API key) para leerla en tiempo de ejecución.

## Qué función cumple

Las credenciales no deben ir en el código, en un issue ni en el estado de Terraform. Este módulo crea el **contenedor** del secreto y deja su valor real fuera de Terraform:

1. Terraform crea el secreto con un valor de marcador, `CAMBIAR-ESTE-VALOR`.
2. Una persona carga el valor real con la CLI o la consola de AWS.
3. `ignore_changes` evita que Terraform vuelva a sobrescribirlo en el siguiente `apply`.

Así, la credencial real nunca pasa por el código, por un Pull Request ni por el archivo de estado.

El módulo **no concede acceso de lectura a ninguna aplicación**. Para eso se usa [iam-secret-reader](../iam-secret-reader/README.md).

## Qué hace cada archivo

| Archivo | Función |
|---|---|
| [main.tf](main.tf) | Declara `aws_secretsmanager_secret` (el secreto, con descripción, ventana de recuperación y cifrado) y `aws_secretsmanager_secret_version` (la versión con el valor de marcador y `ignore_changes` sobre `secret_string`). |
| [variables.tf](variables.tf) | Define lo que se puede configurar, con valores por defecto y validaciones. |
| [outputs.tf](outputs.tf) | Define los datos que el módulo devuelve. |
| [versions.tf](versions.tf) | Fija la versión mínima de Terraform (`>= 1.5.0`) y del provider de AWS (`>= 5.0, < 7.0`). |

## Entradas (variables)

| Variable | Tipo | Por defecto | Descripción |
|---|---|---|---|
| `secret_name` | `string` | — (obligatoria) | Nombre del secreto, por ejemplo `pagos/dev/db-password`. De 1 a 512 caracteres: letras, números y `/ _ + = . @ -`. |
| `secret_description` | `string` | `Secreto gestionado por Terraform` | Qué credencial guarda y qué aplicación la usa. |
| `recovery_window_in_days` | `number` | `7` | Días que el secreto sigue recuperable tras borrarlo (7 a 30). `0` lo elimina de inmediato. |
| `kms_key_id` | `string` | `null` | ARN o alias de una clave KMS propia; si es `null`, AWS usa su clave gestionada. |
| `tags` | `map(string)` | `{}` | Etiquetas que se aplican al secreto. |

## Resultado que devuelve (outputs)

| Output | Qué contiene | Para qué se usa |
|---|---|---|
| `secret_arn` | ARN del secreto | Escribir políticas IAM y referenciarlo desde la aplicación |
| `secret_name` | Nombre del secreto | Pedir el valor con `get-secret-value` |

## Ejemplo de uso

```hcl
module "secrets_manager" {
  source = "../../modules/secrets-manager"

  secret_name        = "pagos/dev/db-password"
  secret_description = "Contraseña de la base de datos de pagos (dev)"
  tags               = { Environment = "dev" }
}
```

Después de `terraform apply`, carga el valor real sin dejarlo en el historial:

```bash
read -s -p "Valor: " SECRETO && echo
aws secretsmanager put-secret-value --secret-id pagos/dev/db-password --secret-string "$SECRETO"
unset SECRETO
```

## Qué hay que saber al borrarlo

`terraform destroy` no elimina el secreto de inmediato: queda en ventana de recuperación (7 días por defecto), y no se puede crear otro con el mismo nombre hasta que termine. Para borrarlo ya:

```bash
aws secretsmanager delete-secret --secret-id <nombre> --force-delete-without-recovery
```

## Política asociada

[policy/secrets.rego](../../policy/secrets.rego) comprueba sobre el plan que la ventana de recuperación sea de al menos 7 días y que ninguna versión lleve un valor real distinto del marcador. Sus tests están en [tests/secrets_test.rego](../../tests/secrets_test.rego).

## Cómo se prueba

```bash
terraform init -backend=false
terraform validate
opa test ../../policy ../../tests
```

Para desplegarlo, usa [examples/dev](../../examples/dev). El usuario de AWS necesita permisos de Secrets Manager; en una cuenta de pruebas sirve la política administrada `SecretsManagerReadWrite`.
