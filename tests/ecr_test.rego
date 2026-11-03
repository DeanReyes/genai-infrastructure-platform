package terraform.ecr_test

import data.terraform.ecr
import rego.v1

repo(after, actions) := {"resource_changes": [{
	"address": "module.ecr.aws_ecr_repository.this",
	"type": "aws_ecr_repository",
	"change": {"actions": actions, "after": after},
}]}

valid_after := {
	"image_tag_mutability": "IMMUTABLE",
	"image_scanning_configuration": [{"scan_on_push": true}],
}

test_valid_repository_has_no_violations if {
	count(ecr.deny) == 0 with input as repo(valid_after, ["create"])
}

test_scan_on_push_disabled_is_denied if {
	after := object.union(valid_after, {"image_scanning_configuration": [{"scan_on_push": false}]})
	"module.ecr.aws_ecr_repository.this must enable scan_on_push" in ecr.deny with input as repo(after, ["create"])
}

test_missing_scanning_configuration_is_denied if {
	after := {"image_tag_mutability": "IMMUTABLE"}
	"module.ecr.aws_ecr_repository.this must enable scan_on_push" in ecr.deny with input as repo(after, ["create"])
}

test_mutable_tags_are_denied if {
	after := object.union(valid_after, {"image_tag_mutability": "MUTABLE"})
	"module.ecr.aws_ecr_repository.this must set image_tag_mutability to IMMUTABLE" in ecr.deny with input as repo(after, ["create"])
}

test_insecure_repository_reports_both_violations if {
	after := {"image_tag_mutability": "MUTABLE", "image_scanning_configuration": [{"scan_on_push": false}]}
	count(ecr.deny) == 2 with input as repo(after, ["create"])
}

test_repository_being_deleted_is_ignored if {
	count(ecr.deny) == 0 with input as repo(null, ["delete"])
}

test_unrelated_resources_are_ignored if {
	other := {"resource_changes": [{
		"address": "aws_s3_bucket.x",
		"type": "aws_s3_bucket",
		"change": {"actions": ["create"], "after": {}},
	}]}
	count(ecr.deny) == 0 with input as other
}
