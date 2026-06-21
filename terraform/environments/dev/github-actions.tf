# GitHub Actions OIDC federation for CI/CD
# Enables GitHub Actions workflows in spring-petclinic-microservices to
# authenticate with AWS and push container images to ECR.
#
# NOTE: repository_dispatch to the platform repo is a GitHub Actions workflow
# token permission (configured via `permissions: contents: write` in the
# workflow YAML), not an AWS IAM permission. It is independent of this
# OIDC-fed IAM role.

locals {
  github_oidc_url = "token.actions.githubusercontent.com"
  github_audience = "sts.amazonaws.com"
  github_repo     = "stephcloud/spring-petclinic-microservices"
  github_ref      = "refs/heads/main"
}

# Fetch the GitHub OIDC provider TLS certificate thumbprints dynamically.
data "tls_certificate" "github" {
  url = "https://${local.github_oidc_url}"
}

# OIDC provider for GitHub Actions.
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://${local.github_oidc_url}"
  client_id_list  = [local.github_audience]
  thumbprint_list = data.tls_certificate.github.certificates[*].sha1_fingerprint

  tags = {
    Name = "github-actions-oidc"
  }
}

# Trust policy: allow GitHub Actions from the specified repo/branch to assume
# this role via OIDC.
data "aws_iam_policy_document" "github_actions_trust" {
  statement {
    sid    = "GitHubActionsOIDC"
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "${local.github_oidc_url}:aud"
      values   = [local.github_audience]
    }

    condition {
      test     = "StringLike"
      variable = "${local.github_oidc_url}:sub"
      values   = ["repo:${local.github_repo}:ref:${local.github_ref}"]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "petclinic-github-actions-role"
  assume_role_policy = data.aws_iam_policy_document.github_actions_trust.json

  tags = {
    Name = "petclinic-github-actions-role"
  }
}

# Permissions policy: ECR push only.
data "aws_iam_policy_document" "github_actions_ecr" {
  statement {
    sid    = "GetAuthorizationToken"
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ECRPush"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:PutImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "github_actions_ecr" {
  name        = "petclinic-github-actions-ecr-push"
  description = "Allows GitHub Actions to push container images to ECR"
  policy      = data.aws_iam_policy_document.github_actions_ecr.json

  tags = {
    Name = "petclinic-github-actions-ecr-push"
  }
}

resource "aws_iam_role_policy_attachment" "github_actions_ecr" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.github_actions_ecr.arn
}
