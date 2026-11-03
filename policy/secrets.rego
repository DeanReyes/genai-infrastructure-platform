package terraform.secrets

import rego.v1

# Valor de marcador que escribe modules/secrets-manager; el valor real se carga fuera de Terraform.
placeholder := "CAMBIAR-ESTE-VALOR"

secrets contains rc if {
	some rc in input.resource_changes
	rc.type == "aws_secretsmanager_secret"
	rc.change.actions != ["delete"]
}

secret_versions contains rc if {
	some rc in input.resource_changes
	rc.type == "aws_secretsmanager_secret_version"
	rc.change.actions != ["delete"]
}

# null significa que AWS aplica su valor por defecto (30 dias), que es aceptable.
recovery_window_ok(rc) if {
	object.get(rc.change.after, "recovery_window_in_days", null) == null
}

recovery_window_ok(rc) if {
	rc.change.after.recovery_window_in_days >= 7
}

deny contains msg if {
	some rc in secrets
	not recovery_window_ok(rc)
	msg := sprintf("%s must keep a recovery window of at least 7 days", [rc.address])
}

deny contains msg if {
	some rc in secret_versions
	object.get(rc.change.after, "secret_string", placeholder) != placeholder
	msg := sprintf("%s must not carry a real secret value in Terraform; load it outside Terraform", [rc.address])
}
