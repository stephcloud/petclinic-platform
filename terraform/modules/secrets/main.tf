locals {
  name_prefix = "petclinic-${var.environment}"
  common_tags = merge(
    {
      Project     = "petclinic"
      Environment = var.environment
      ManagedBy   = "terraform"
    },
    var.tags
  )
}

# ---------------------------------------------------------------------------
# OpenAI API Key — placeholder secret in Secrets Manager
# ---------------------------------------------------------------------------
resource "aws_secretsmanager_secret" "openai_api_key" {
  name        = "petclinic/${var.environment}/openai-api-key"
  description = "OpenAI API key for ${local.name_prefix} genai-service"

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-openai-api-key" })
}

resource "aws_secretsmanager_secret_version" "openai_api_key" {
  secret_id     = aws_secretsmanager_secret.openai_api_key.id
  secret_string = "REPLACE_ME"
}

# ---------------------------------------------------------------------------
# External Secrets Operator — IRSA Role
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "eso_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_provider_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:external-secrets:external-secrets"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_provider_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eso" {
  name               = "${local.name_prefix}-external-secrets-role"
  assume_role_policy = data.aws_iam_policy_document.eso_assume_role.json

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-external-secrets-role" })
}

# ---------------------------------------------------------------------------
# ESO Policy — Secrets Manager read-only for petclinic/*
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "eso_secrets" {
  statement {
    sid    = "AllowReadPetclinicSecrets"
    effect = "Allow"

    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
    ]

    resources = [
      "arn:aws:secretsmanager:*:*:secret:petclinic/*",
    ]
  }
}

resource "aws_iam_policy" "eso_secrets" {
  name        = "${local.name_prefix}-external-secrets-policy"
  description = "Allow ESO to read petclinic secrets in AWS Secrets Manager"
  policy      = data.aws_iam_policy_document.eso_secrets.json

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-external-secrets-policy" })
}

resource "aws_iam_role_policy_attachment" "eso_secrets" {
  policy_arn = aws_iam_policy.eso_secrets.arn
  role       = aws_iam_role.eso.name
}
