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
