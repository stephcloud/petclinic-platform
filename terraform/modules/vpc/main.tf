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
# VPC
# ---------------------------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-vpc"
    }
  )
}

# ---------------------------------------------------------------------------
# Internet Gateway
# ---------------------------------------------------------------------------
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-igw"
    }
  )
}

# ---------------------------------------------------------------------------
# Public Subnets
# ---------------------------------------------------------------------------
resource "aws_subnet" "public" {
  count = length(var.availability_zones)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(
    local.common_tags,
    {
      Name                                                 = "${local.name_prefix}-public-${var.availability_zones[count.index]}"
      "kubernetes.io/cluster/petclinic-${var.environment}" = "shared"
      "kubernetes.io/role/elb"                             = "1"
    }
  )
}

# ---------------------------------------------------------------------------
# Route Table (public — single table for all public subnets)
# ---------------------------------------------------------------------------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-public-rt"
    }
  )
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ---------------------------------------------------------------------------
# Security Groups
# ---------------------------------------------------------------------------

# --- EKS Cluster Security Group ---
resource "aws_security_group" "eks_cluster" {
  name        = "${local.name_prefix}-eks-cluster-sg"
  description = "Security group for EKS cluster control plane"
  vpc_id      = aws_vpc.main.id

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-eks-cluster-sg"
    }
  )
}

resource "aws_vpc_security_group_ingress_rule" "eks_cluster_from_nodes" {
  security_group_id = aws_security_group.eks_cluster.id

  description                  = "API Server access from EKS nodes"
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.eks_node.id
}

resource "aws_vpc_security_group_egress_rule" "eks_cluster_egress" {
  security_group_id = aws_security_group.eks_cluster.id

  description = "Allow all outbound traffic"
  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"
}

# --- EKS Node Security Group ---
resource "aws_security_group" "eks_node" {
  name        = "${local.name_prefix}-eks-node-sg"
  description = "Security group for EKS worker nodes"
  vpc_id      = aws_vpc.main.id

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-eks-node-sg"
    }
  )
}

resource "aws_vpc_security_group_ingress_rule" "eks_node_from_cluster" {
  security_group_id = aws_security_group.eks_node.id

  description                  = "All traffic from EKS cluster SG"
  ip_protocol                  = "-1"
  referenced_security_group_id = aws_security_group.eks_cluster.id
}

resource "aws_vpc_security_group_ingress_rule" "eks_node_self" {
  security_group_id = aws_security_group.eks_node.id

  description                  = "Inter-node communication"
  ip_protocol                  = "-1"
  referenced_security_group_id = aws_security_group.eks_node.id
}

resource "aws_vpc_security_group_ingress_rule" "eks_node_kubelet" {
  security_group_id = aws_security_group.eks_node.id

  description                  = "Kubelet API from cluster"
  from_port                    = 10250
  to_port                      = 10250
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.eks_cluster.id
}

resource "aws_vpc_security_group_ingress_rule" "eks_node_nodeport" {
  security_group_id = aws_security_group.eks_node.id

  description                  = "NodePort services from ALB"
  from_port                    = 30000
  to_port                      = 32767
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.alb.id
}

resource "aws_vpc_security_group_egress_rule" "eks_node_egress" {
  security_group_id = aws_security_group.eks_node.id

  description = "Allow all outbound traffic"
  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"
}

# --- RDS Security Group ---
resource "aws_security_group" "rds" {
  name        = "${local.name_prefix}-rds-sg"
  description = "Security group for RDS MySQL"
  vpc_id      = aws_vpc.main.id

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-rds-sg"
    }
  )
}

resource "aws_vpc_security_group_ingress_rule" "rds_from_nodes" {
  security_group_id = aws_security_group.rds.id

  description                  = "MySQL from EKS nodes"
  from_port                    = 3306
  to_port                      = 3306
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.eks_node.id
}

# --- ALB Security Group ---
resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = aws_vpc.main.id

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-alb-sg"
    }
  )
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id

  description = "HTTP from internet"
  from_port   = 80
  to_port     = 80
  ip_protocol = "tcp"
  cidr_ipv4   = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id

  description = "HTTPS from internet"
  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"
  cidr_ipv4   = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "alb_to_nodes_nodeport" {
  security_group_id = aws_security_group.alb.id

  description                  = "To nodes (target group NodePort)"
  from_port                    = 30000
  to_port                      = 32767
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.eks_node.id
}

resource "aws_vpc_security_group_egress_rule" "alb_to_nodes_health" {
  security_group_id = aws_security_group.alb.id

  description                  = "Health checks to nodes"
  from_port                    = 8080
  to_port                      = 8080
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.eks_node.id
}
