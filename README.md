# genai-infrastructure-platform

Plataforma de aprendizaje para pedir infraestructura en AWS mediante **GitHub Issues**: un asistente con IA entiende la solicitud, la valida contra un catálogo de módulos de Terraform y propone el código en un Pull Request. Combina módulos de Terraform, GenAI, GitHub Actions y Policy as Code (OPA/Rego).

> Es un proyecto de laboratorio, no una plataforma lista para producción. Revisa siempre el código generado antes de aplicarlo.

## Qué incluye

| Carpeta | Contenido |
|---|---|
| [modules/](modules/) | Módulos de Terraform reutilizables (ver la tabla siguiente). |
| [policy/](policy/) | Políticas de OPA/Rego que validan el plan de Terraform. |
| [tests/](tests/) | Pruebas de OPA para cada política. |
| [examples/dev/](examples/dev/) | Configuración de ejemplo que despliega los módulos en un entorno de pruebas. |
| [src/](src/) | Código Python del Copilot: `copilot.py` y `module_catalog.py`. |
| [.github/](.github/) | Plantilla de issue y los workflows `issue-intake` e `issue-copilot`. |

## Módulos

| Módulo | Qué crea | Documentación |
|---|---|---|
| `ecr` | Repositorio de imágenes Docker con escaneo en push, tags inmutables y limpieza automática. | [modules/ecr](modules/ecr/README.md) |
| `secrets-manager` | Secreto cifrado con un valor de marcador; el valor real se carga fuera de Terraform. | [modules/secrets-manager](modules/secrets-manager/README.md) |
| `iam-secret-reader` | Rol de IAM que solo puede leer los secretos indicados. | [modules/iam-secret-reader](modules/iam-secret-reader/README.md) |

El Copilot descubre los módulos automáticamente leyendo `modules/*/variables.tf`, así que un módulo nuevo aparece en el catálogo sin tocar el código.

## Cómo funciona el flujo por issues

1. **Se abre un issue** con la plantilla *Infrastructure request*, que añade la etiqueta `infrastructure-request`.
2. **Intake:** el workflow `issue-intake` responde con los módulos disponibles y los datos necesarios.
3. **Copilot:** el workflow `issue-copilot` usa un LLM (API compatible con OpenAI) para extraer el módulo, los parámetros, el entorno y la región en un esquema JSON restringido.
4. **Validación determinista:** el código comprueba el resultado contra el catálogo. Si faltan datos, los pide en el propio issue; se pueden responder con líneas `clave: valor`, por ejemplo `region: us-east-1`.
5. **Repositorio y Pull Request:** con los datos completos, crea el repositorio `infra-<aplicación>` a partir de la plantilla `terraform-infrastructure-template`, y abre un Pull Request con un `main.tf` que referencia el módulo elegido y un `REQUEST.md` con el resumen de la solicitud.
6. **Revisión:** el workflow de validación de la plantilla ejecuta `terraform init` y `terraform validate` en el Pull Request. Una persona lo revisa y decide.

El workflow `issue-copilot` se divide en tres jobs encadenados, que se ven como un grafo en la pestaña **Actions**:

| Job | Qué hace | Secretos que usa |
|---|---|---|
| `extraer` | El LLM extrae los parámetros del issue (`python src/copilot.py extract`). | `LLM_API_KEY` |
| `validar` | Los contrasta con el catálogo; si faltan datos, los pide en el issue y se detiene (`validate`). | Ninguno propio |
| `proponer` | Crea el repositorio y abre el Pull Request (`propose`). | `GH_PLATFORM_TOKEN` |

Los datos pasan de un job al siguiente como *outputs* (parámetros de la solicitud, nunca secretos), y cada job declara solo los permisos que necesita.

Si ya existe un repositorio para esa aplicación y su README coincide con la plantilla, se reutiliza en lugar de crear otro.

## Configuración

En **Settings → Secrets and variables → Actions** del repositorio:

| Nombre | Tipo | Obligatorio | Descripción |
|---|---|---|---|
| `LLM_API_KEY` | Secreto | Sí | Clave de la API del proveedor del LLM. |
| `GH_PLATFORM_TOKEN` | Secreto | Sí | Token personal clásico con permisos `repo` y `workflow`, para crear repositorios y abrir Pull Requests. |
| `LLM_MODEL` | Variable | No | Identificador del modelo. Por defecto, `gpt-4o-mini`. |
| `LLM_BASE_URL` | Variable | No | URL base de la API. Por defecto, `https://api.openai.com/v1`. |

Además:

- Crea la etiqueta `infrastructure-request` en el repositorio.
- El repositorio `terraform-infrastructure-template` debe ser público y estar marcado como **Template repository**.
- En **Settings → Actions → General**, permite los workflows y los permisos de lectura y escritura.

Usa una cuenta y un modelo a los que tengas acceso. El uso de la API puede generar costes, y GitHub Free no incluye créditos de LLM.

## Límites de seguridad

- **No hay `terraform apply` automático.** El flujo solo propone código en un Pull Request.
- **El LLM solo extrae parámetros.** El código los valida de forma determinista contra el catálogo.
- **El origen del módulo es fijo:** este mismo repositorio público.
- **Solo propietarios, miembros y colaboradores** disparan los workflows. Los issues de usuarios externos se ignoran, para que nadie gaste tu clave del LLM ni cree repositorios con tu token.
- **No pongas secretos ni datos de clientes en los issues.** El valor real de un secreto se carga con la CLI de AWS, fuera de Terraform.
- Las políticas de `policy/` comprueban el plan de Terraform: escaneo e inmutabilidad en ECR, ventana de recuperación y ausencia de valores reales en secretos, y roles IAM sin comodines.

## Probar en local

```bash
# Pruebas de las políticas
opa test policy tests

# Validar un módulo
cd modules/ecr
terraform init -backend=false
terraform validate

# Planificar el ejemplo y evaluar las políticas
cd ../../examples/dev
terraform init
terraform plan -out tfplan
terraform show -json tfplan > tfplan.json
opa eval -d ../../policy -i tfplan.json "data.terraform.ecr.deny" -f pretty
```

Para desplegar el ejemplo (`terraform apply tfplan`) hacen falta credenciales de AWS con permisos sobre ECR, Secrets Manager e IAM, preferiblemente en una cuenta de pruebas. Al terminar, ejecuta `terraform destroy` en `examples/dev`.

## Limitaciones conocidas

- Las políticas de OPA todavía **no se ejecutan en CI**: hay que lanzarlas a mano.
- `iam-secret-reader` necesita ARN de secretos que ya existan, así que encaja mal con el flujo por issues, donde quien pide el recurso no los conoce de antemano.
- El Copilot lee todos los comentarios del issue como contexto, incluidos los de usuarios externos, aunque los workflows no se disparen por ellos.

## Repositorios relacionados

- [terraform-infrastructure-template](https://github.com/DeanReyes/terraform-infrastructure-template): plantilla de la que nacen los repositorios `infra-<aplicación>`.
- [cloud-governance](https://github.com/DeanReyes/cloud-governance): repositorio de gobernanza enlazado originalmente. Las políticas de este proyecto viven ahora en [policy/](policy/).
