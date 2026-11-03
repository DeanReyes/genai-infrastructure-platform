package terraform.ecr

import rego.v1

# Evalua el plan de Terraform en JSON (terraform show -json tfplan).
# Se ignoran los repositorios que el plan va a borrar.

repositories contains rc if {
	some rc in input.resource_changes
	rc.type == "aws_ecr_repository"
	rc.change.actions != ["delete"]
}

scan_on_push_enabled(rc) if {
	rc.change.after.image_scanning_configuration[0].scan_on_push == true
}

deny contains msg if {
	some rc in repositories
	not scan_on_push_enabled(rc)
	msg := sprintf("%s must enable scan_on_push", [rc.address])
}

deny contains msg if {
	some rc in repositories
	object.get(rc.change.after, "image_tag_mutability", "") != "IMMUTABLE"
	msg := sprintf("%s must set image_tag_mutability to IMMUTABLE", [rc.address])
}
