output "openai_secret_arn" {
  description = "ARN of the OpenAI API key secret in Secrets Manager"
  value       = aws_secretsmanager_secret.openai_api_key.arn
}

output "eso_role_arn" {
  description = "IAM role ARN for External Secrets Operator (IRSA)"
  value       = aws_iam_role.eso.arn
}

output "eso_role_name" {
  description = "IAM role name for External Secrets Operator (IRSA)"
  value       = aws_iam_role.eso.name
}
