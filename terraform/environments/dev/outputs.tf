# VPC outputs
output "vpc_id" {
  description = "ID of the created VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

# EKS outputs
output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint URL for the EKS cluster API server"
  value       = module.eks.cluster_endpoint
}

output "cluster_ca_certificate" {
  description = "Base64-encoded certificate data for the EKS cluster"
  value       = module.eks.cluster_ca_certificate
}

output "node_group_name" {
  description = "Name of the managed EKS node group"
  value       = module.eks.node_group_name
}

output "node_role_arn" {
  description = "ARN of the IAM role assigned to EKS worker nodes"
  value       = module.eks.node_role_arn
}

# RDS outputs
output "rds_endpoint" {
  description = "RDS instance endpoint address"
  value       = module.rds.endpoint
}

output "rds_port" {
  description = "RDS instance port"
  value       = module.rds.port
}

output "rds_instance_id" {
  description = "RDS instance identifier"
  value       = module.rds.db_instance_id
}

output "rds_secret_arn" {
  description = "ARN of the Secrets Manager secret containing RDS credentials"
  value       = module.rds.secret_arn
}

# ECR outputs
output "ecr_repository_urls" {
  description = "Map of service name to ECR repository URL"
  value       = module.ecr.repository_urls
}

output "ecr_repository_arns" {
  description = "Map of service name to ECR repository ARN"
  value       = module.ecr.repository_arns
}

# Secrets outputs
output "eso_role_arn" {
  description = "IAM role ARN for External Secrets Operator (IRSA)"
  value       = module.secrets.eso_role_arn
}

output "openai_secret_arn" {
  description = "ARN of the OpenAI API key secret in Secrets Manager"
  value       = module.secrets.openai_secret_arn
}
