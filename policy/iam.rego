package terraform.iam

import rego.v1

# Evalua el plan de Terraform en JSON (terraform show -json tfplan).
# Se ignoran los recursos que el plan va a borrar. Si una politica aun es
# desconocida (se calcula al aplicar), todavia no hay nada que evaluar.

roles contains rc if {
	some rc in input.resource_changes
	rc.type == "aws_iam_role"
	rc.change.actions != ["delete"]
}

role_policies contains rc if {
	some rc in input.resource_changes
	rc.type == "aws_iam_role_policy"
	rc.change.actions != ["delete"]
}

to_array(x) := x if is_array(x)

to_array(x) := [x] if not is_array(x)

wildcard_principal(stmt) if stmt.Principal == "*"

wildcard_principal(stmt) if "*" in to_array(stmt.Principal.AWS)

deny contains msg if {
	some rc in roles
	doc := json.unmarshal(rc.change.after.assume_role_policy)
	some stmt in to_array(doc.Statement)
	wildcard_principal(stmt)
	msg := sprintf("%s must not allow any principal (*) to assume the role", [rc.address])
}

deny contains msg if {
	some rc in role_policies
	doc := json.unmarshal(rc.change.after.policy)
	some stmt in to_array(doc.Statement)
	stmt.Effect == "Allow"
	some action in to_array(stmt.Action)
	endswith(action, "*")
	msg := sprintf("%s must not allow wildcard actions (%s)", [rc.address, action])
}

deny contains msg if {
	some rc in role_policies
	doc := json.unmarshal(rc.change.after.policy)
	some stmt in to_array(doc.Statement)
	stmt.Effect == "Allow"
	some resource in to_array(stmt.Resource)
	resource == "*"
	msg := sprintf("%s must not grant access to all resources (*)", [rc.address])
}
