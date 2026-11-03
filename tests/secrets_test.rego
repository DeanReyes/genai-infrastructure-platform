package terraform.secrets_test

import data.terraform.secrets
import rego.v1

secret_rc(after, actions) := {
	"address": "module.sm.aws_secretsmanager_secret.this",
	"type": "aws_secretsmanager_secret",
	"change": {"actions": actions, "after": after},
}

version_rc(after, actions) := {
	"address": "module.sm.aws_secretsmanager_secret_version.placeholder",
	"type": "aws_secretsmanager_secret_version",
	"change": {"actions": actions, "after": after},
}

plan(rcs) := {"resource_changes": rcs}

test_valid_secret_with_placeholder_has_no_violations if {
	count(secrets.deny) == 0 with input as plan([
		secret_rc({"recovery_window_in_days": 7}, ["create"]),
		version_rc({"secret_string": "CAMBIAR-ESTE-VALOR"}, ["create"]),
	])
}

test_recovery_window_of_30_is_allowed if {
	count(secrets.deny) == 0 with input as plan([secret_rc({"recovery_window_in_days": 30}, ["create"])])
}

test_null_recovery_window_uses_aws_default_and_is_allowed if {
	count(secrets.deny) == 0 with input as plan([secret_rc({"recovery_window_in_days": null}, ["create"])])
}

test_zero_recovery_window_is_denied if {
	"module.sm.aws_secretsmanager_secret.this must keep a recovery window of at least 7 days" in secrets.deny with input as plan([secret_rc({"recovery_window_in_days": 0}, ["create"])])
}

test_short_recovery_window_is_denied if {
	"module.sm.aws_secretsmanager_secret.this must keep a recovery window of at least 7 days" in secrets.deny with input as plan([secret_rc({"recovery_window_in_days": 3}, ["create"])])
}

test_real_secret_value_is_denied if {
	count(secrets.deny) == 1 with input as plan([version_rc({"secret_string": "hunter2"}, ["create"])])
}

test_secret_being_deleted_is_ignored if {
	count(secrets.deny) == 0 with input as plan([secret_rc({"recovery_window_in_days": 0}, ["delete"])])
}

test_unrelated_resources_are_ignored if {
	count(secrets.deny) == 0 with input as plan([{
		"address": "aws_s3_bucket.x",
		"type": "aws_s3_bucket",
		"change": {"actions": ["create"], "after": {}},
	}])
}
