package terraform.iam_test

import data.terraform.iam
import rego.v1

role_rc(trust, actions) := {
	"address": "module.iam.aws_iam_role.this",
	"type": "aws_iam_role",
	"change": {"actions": actions, "after": {"assume_role_policy": json.marshal(trust)}},
}

policy_rc(doc, actions) := {
	"address": "module.iam.aws_iam_role_policy.read_secrets",
	"type": "aws_iam_role_policy",
	"change": {"actions": actions, "after": {"policy": json.marshal(doc)}},
}

plan(rcs) := {"resource_changes": rcs}

secret_arn := "arn:aws:secretsmanager:us-east-1:123456789012:secret:demo/dev/db-password-abc123"

trust_with(principal) := {"Version": "2012-10-17", "Statement": [{"Effect": "Allow", "Action": "sts:AssumeRole", "Principal": principal}]}

policy_with(actions, resources) := {"Version": "2012-10-17", "Statement": [{"Effect": "Allow", "Action": actions, "Resource": resources}]}

trust_ok := trust_with({"AWS": "arn:aws:iam::123456789012:user/dean"})

policy_ok := policy_with(["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"], secret_arn)

test_valid_role_and_policy_have_no_violations if {
	count(iam.deny) == 0 with input as plan([role_rc(trust_ok, ["create"]), policy_rc(policy_ok, ["create"])])
}

test_wildcard_principal_in_object_is_denied if {
	"module.iam.aws_iam_role.this must not allow any principal (*) to assume the role" in iam.deny with input as plan([role_rc(trust_with({"AWS": "*"}), ["create"])])
}

test_wildcard_principal_as_string_is_denied if {
	"module.iam.aws_iam_role.this must not allow any principal (*) to assume the role" in iam.deny with input as plan([role_rc(trust_with("*"), ["create"])])
}

test_wildcard_principal_inside_list_is_denied if {
	"module.iam.aws_iam_role.this must not allow any principal (*) to assume the role" in iam.deny with input as plan([role_rc(trust_with({"AWS": ["arn:aws:iam::123456789012:user/dean", "*"]}), ["create"])])
}

test_wildcard_resource_is_denied if {
	"module.iam.aws_iam_role_policy.read_secrets must not grant access to all resources (*)" in iam.deny with input as plan([policy_rc(policy_with(["secretsmanager:GetSecretValue"], "*"), ["create"])])
}

test_wildcard_action_is_denied if {
	"module.iam.aws_iam_role_policy.read_secrets must not allow wildcard actions (secretsmanager:*)" in iam.deny with input as plan([policy_rc(policy_with(["secretsmanager:*"], secret_arn), ["create"])])
}

test_role_being_deleted_is_ignored if {
	count(iam.deny) == 0 with input as plan([role_rc(trust_with({"AWS": "*"}), ["delete"])])
}

test_unknown_policy_is_ignored if {
	count(iam.deny) == 0 with input as plan([{
		"address": "module.iam.aws_iam_role_policy.read_secrets",
		"type": "aws_iam_role_policy",
		"change": {"actions": ["create"], "after": {}},
	}])
}

test_unrelated_resources_are_ignored if {
	count(iam.deny) == 0 with input as plan([{
		"address": "aws_s3_bucket.x",
		"type": "aws_s3_bucket",
		"change": {"actions": ["create"], "after": {}},
	}])
}
