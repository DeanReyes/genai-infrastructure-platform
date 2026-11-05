# Quien puede asumir el rol: solo las identidades indicadas, nunca un comodin.
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = var.trusted_principal_arns
    }
  }
}

# Que puede hacer el rol: solo leer los secretos indicados.
data "aws_iam_policy_document" "read_secrets" {
  statement {
    sid       = "ReadSecrets"
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = var.secret_arns
  }

  # Solo si los secretos usan una clave KMS propia hace falta poder descifrarlos.
  dynamic "statement" {
    for_each = length(var.kms_key_arns) > 0 ? [1] : []

    content {
      sid       = "DecryptSecrets"
      effect    = "Allow"
      actions   = ["kms:Decrypt"]
      resources = var.kms_key_arns
    }
  }
}

resource "aws_iam_role" "this" {
  name                 = var.role_name
  assume_role_policy   = data.aws_iam_policy_document.assume_role.json
  max_session_duration = var.max_session_duration

  tags = var.tags
}

resource "aws_iam_role_policy" "read_secrets" {
  name   = "read-secrets"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.read_secrets.json
}
