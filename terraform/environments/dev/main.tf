# Dev environment root module — calls reusable modules from terraform/modules/

module "vpc" {
  source = "../../modules/vpc"

  environment = var.environment
  vpc_cidr    = "10.0.0.0/16"
  public_subnet_cidrs = [
    "10.0.1.0/24",
    "10.0.2.0/24",
  ]
  availability_zones = [
    "eu-central-1a",
    "eu-central-1b",
  ]
}

module "eks" {
  source = "../../modules/eks"

  environment       = var.environment
  vpc_id            = module.vpc.vpc_id
  subnet_ids        = module.vpc.public_subnet_ids
  eks_cluster_sg_id = module.vpc.eks_cluster_sg_id
  eks_node_sg_id    = module.vpc.eks_node_sg_id
}
