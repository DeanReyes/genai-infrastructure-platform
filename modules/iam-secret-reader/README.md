# Módulo iam-secret-reader

Crea un **rol de IAM** que solo puede leer los secretos de Secrets Manager que se le indiquen, y que solo pueden asumir las identidades autorizadas.

## Qué función cumple

El módulo [secrets-manager](../secrets-manager/README.md) crea el secreto, pero no da acceso a ninguna aplicación. Este módulo cubre ese hueco aplicando el **mínimo privilegio**:

- **Quién puede usar el rol:** solo los usuarios o roles de IAM listados en `trusted_principal_arns`. Nunca un comodín.
- **Qué puede hacer:** únicamente `GetSecretValue` y `DescribeSecret` sobre los ARN listados en `secret_arns`. Si el secreto usa una clave KMS propia, añade `kms:Decrypt` sobre esa clave.

Una aplicación asume el rol y obtiene credenciales temporales; con ellas puede leer su secreto, pero cualquier otro secreto de la cuenta le devuelve `AccessDenied`.

## Qué hace cada archivo

| Archivo | Función |
|---|---|
| [main.tf](main.tf) | Declara dos documentos de política (`assume_role`, quién puede asumir el rol, y `read_secrets`, qué puede leer), el rol `aws_iam_role` y la política en línea `aws_iam_role_policy`. El bloque `kms:Decrypt` solo aparece si se indican claves KMS. |
| [variables.tf](variables.tf) | Define lo que se puede configurar, con validaciones del formato de los ARN y de la duración de la sesión. |
| [outputs.tf](outputs.tf) | Define los datos que el módulo devuelve. |
| [versions.tf](versions.tf) | Fija la versión mínima de Terraform (`>= 1.5.0`) y del provider de AWS (`>= 5.0, < 7.0`). |

## Entradas (variables)

| Variable | Tipo | Por defecto | Descripción |
|---|---|---|---|
| `role_name` | `string` | — (obligatoria) | Nombre del rol, por ejemplo `pagos-dev-secret-reader`. De 1 a 64 caracteres. |
| `secret_arns` | `list(string)` | — (obligatoria) | ARN de los secretos que el rol puede leer. Al menos uno, con formato `arn:aws:secretsmanager:región:cuenta:secret:nombre`. |
| `trusted_principal_arns` | `list(string)` | — (obligatoria) | ARN de los usuarios o roles que pueden asumir el rol. Al menos uno. |
| `kms_key_arns` | `list(string)` | `[]` | Claves KMS propias de los secretos; si está vacía no se concede `kms:Decrypt`. |
| `max_session_duration` | `number` | `3600` | Duración máxima de la sesión en segundos (3600 a 43200). |
| `tags` | `map(string)` | `{}` | Etiquetas que se aplican al rol. |

## Resultado que devuelve (outputs)

| Output | Qué contiene | Para qué se usa |
|---|---|---|
| `role_arn` | ARN del rol | Asumirlo con `sts assume-role` o asignarlo a la aplicación (tarea de ECS, pod de EKS) |
| `role_name` | Nombre del rol | Referenciarlo desde otros recursos |

## Ejemplo de uso

```hcl
data "aws_caller_identity" "current" {}

module "secret_reader" {
  source = "../../modules/iam-secret-reader"

  role_name              = "pagos-dev-secret-reader"
  secret_arns            = [module.secrets_manager.secret_arn]
  trusted_principal_arns = [data.aws_caller_identity.current.arn]
  tags                   = { Environment = "dev" }
}
```

En una aplicación real, `trusted_principal_arns` llevaría el rol de ejecución de la tarea o del pod, no el usuario que ejecuta Terraform.

## Cómo se demuestra que funciona

Tras el `apply`:

```bash
aws sts assume-role --role-arn <role_arn> --role-session-name prueba
```

Con las credenciales temporales que devuelve, `aws secretsmanager get-secret-value --secret-id <secreto permitido>` funciona, y el mismo comando sobre otro secreto falla con `AccessDenied`.

## Política asociada

[policy/iam.rego](../../policy/iam.rego) comprueba sobre el plan que ningún rol pueda ser asumido por cualquier principal (`*`) y que ninguna política conceda acciones con comodín ni acceso a todos los recursos. Sus tests están en [tests/iam_test.rego](../../tests/iam_test.rego).

Limitación: si el ARN del secreto se calcula durante el `apply`, el plan todavía no contiene el JSON de la política y esa parte no se puede comprobar en el plan.

## Limitaciones

- Requiere ARN de secretos que ya existan o que se creen en la misma configuración. Por eso no encaja bien con el flujo por issues, donde quien pide el recurso no conoce el ARN de antemano.
- En el repositorio, el rol está definido y planificado en [examples/dev](../../examples/dev), pero puede no estar desplegado en AWS hasta que se ejecute `terraform apply`.

## Cómo se prueba

```bash
terraform init -backend=false
terraform validate
opa test ../../policy ../../tests
```

Para desplegarlo, el usuario de AWS necesita permisos de IAM para crear roles (`iam:CreateRole`, `iam:PutRolePolicy` y relacionados). No lo he verificado con permisos mínimos; en una cuenta de pruebas basta `IAMFullAccess`.
