# Petclinic Platform — Complete Beginner Guide

> Deploy Google's Spring Petclinic Microservices on AWS using Terraform, GitHub Actions, ArgoCD, Kubernetes, Helm, Prometheus, and Grafana.
> Written for beginners. Every step explained. Free tier optimized.

> For infrastructure architecture details and tech stack, see [README-ARCHITECTURE.md](README-ARCHITECTURE.md)

---

## Table of Contents

1. [What You Are Building](#1-what-you-are-building)
2. [Two-Repo Architecture](#2-two-repo-architecture)
3. [Tools You Need](#3-tools-you-need)
4. [AWS Free Tier Notes](#4-aws-free-tier-notes)
5. [Prerequisites — Install Everything](#5-prerequisites--install-everything)
6. [Configure AWS](#6-configure-aws)
7. [Clone the Repos](#7-clone-the-repos)
8. [Set Up Your AI Coding Agent (Kimchi)](#8-set-up-your-ai-coding-agent-kimchi)
9. [Phase 0 — Bootstrap AWS State Backend](#9-phase-0--bootstrap-aws-state-backend)
10. [Phase 1 — Terraform VPC + EKS](#10-phase-1--terraform-vpc--eks)
11. [Phase 2 — Terraform RDS MySQL](#11-phase-2--terraform-rds-mysql)
12. [Phase 3 — Container Registry (ECR)](#12-phase-3--container-registry-ecr)
13. [Phase 4 — Secrets Management](#13-phase-4--secrets-management)
14. [Phase 5 — Kubernetes Base Manifests](#14-phase-5--kubernetes-base-manifests)
15. [Phase 6 — Helm Charts](#15-phase-6--helm-charts)
16. [Phase 7 — ArgoCD GitOps](#16-phase-7--argocd-gitops)
17. [Phase 8 — GitHub Actions CI Pipeline](#17-phase-8--github-actions-ci-pipeline)
18. [Phase 9 — Prometheus + Grafana Monitoring](#18-phase-9--prometheus--grafana-monitoring)
19. [Daily Workflow](#19-daily-workflow)
20. [Troubleshooting](#20-troubleshooting)
21. [Cost Reference](#21-cost-reference)

---

## 1. What You Are Building

You are deploying **Spring Petclinic Microservices** — a real-world Java application made of 8 microservices — onto **AWS EKS** (Kubernetes) using a full production-grade DevOps pipeline.

### The 8 Services

| Service | Port | Database | Role |
|---------|------|----------|------|
| config-server | 8888 | No | Centralized config for all services — starts FIRST |
| discovery-server | 8761 | No | Eureka service registry — starts SECOND |
| api-gateway | 8080 | No | Public entry point, routes traffic to all services |
| customers-service | 8081 | MySQL | Manages pet owners and pets |
| visits-service | 8082 | MySQL | Manages vet visit records |
| vets-service | 8083 | MySQL | Manages vet data |
| genai-service | 8084 | Optional | AI-powered features (needs OpenAI key) |
| admin-server | 9090 | No | Spring Boot Admin dashboard |

### Architecture Overview

```
Internet
   │
   ▼
AWS ALB (Load Balancer)
   │
   ▼
api-gateway (EKS pod)
   ├──→ customers-service
   ├──→ visits-service
   ├──→ vets-service
   └──→ genai-service

All services → RDS MySQL (shared petclinic database)
All services → config-server (centralized config)
All services → discovery-server (Eureka registry)

Monitoring: Prometheus + Grafana + Loki + Alertmanager
Tracing: Zipkin
```

---

## 2. Two-Repo Architecture

This project uses **two GitHub repositories** — this is the standard GitOps pattern used in industry.

| Repo | Purpose | Who modifies it |
|------|---------|----------------|
| `stephcloud/spring-petclinic-microservices` | Application source code, Dockerfiles, CI pipelines | Developers (READ-ONLY for infra) |
| `stephcloud/petclinic-platform` | Terraform, Helm, ArgoCD, K8s manifests | Infrastructure team (YOU) |

### How They Connect

```
spring-petclinic-microservices (App Repo)
  Developer pushes code
       ↓
  GitHub Actions CI runs:
    - Build Docker image (linux/arm64)
    - Trivy security scan
    - Push image to AWS ECR
    - Fire repository_dispatch event → petclinic-platform
       ↓
petclinic-platform (Platform Repo — this repo)
  GitHub Actions receives dispatch:
    - Updates helm-values/{service}.yaml with new image SHA
    - Commits and pushes
       ↓
  ArgoCD detects Git change:
    - Dev: auto-deploys immediately
    - Prod: waits for manual approval
       ↓
  New version running on EKS
```

**Golden Rule:** CI (build/push) lives in the app repo. CD (deploy) is handled by ArgoCD watching the platform repo. Never mix them.

---

## 3. Tools You Need

| Tool | Purpose | Install Guide |
|------|---------|--------------|
| WSL2 (Ubuntu) | Linux environment on Windows | [docs.microsoft.com](https://docs.microsoft.com/en-us/windows/wsl/install) |
| AWS CLI v2 | Talk to AWS | [aws.amazon.com/cli](https://aws.amazon.com/cli/) |
| Terraform >= 1.6 | Infrastructure as Code | [terraform.io](https://developer.hashicorp.com/terraform/install) |
| kubectl | Control Kubernetes cluster | [kubernetes.io](https://kubernetes.io/docs/tasks/tools/) |
| Helm | Package manager for Kubernetes | [helm.sh](https://helm.sh/docs/intro/install/) |
| ArgoCD CLI | Manage ArgoCD from terminal | [argo-cd.readthedocs.io](https://argo-cd.readthedocs.io/en/stable/cli_installation/) |
| Docker | Build container images | [docs.docker.com](https://docs.docker.com/get-docker/) |
| Git | Version control | [git-scm.com](https://git-scm.com/downloads) |
| Kimchi | AI coding agent (free) | See Phase 8 below |
| yq | YAML editor (for CI tag updates) | `pip install yq` |

---

## 4. AWS Free Tier Notes

This project is designed to stay within or near AWS Free Tier limits.

| Resource | Free Tier | Cost When Active |
|----------|-----------|-----------------|
| EKS Control Plane | ❌ Not free — $0.10/hr (~$73/mo) | Always on while cluster exists |
| EC2 t4g.small nodes | ✅ Graviton free trial 750hrs/mo until Dec 2026 | $0 |
| RDS db.t4g.micro | ✅ 750hrs/mo for 12 months | $0 |
| ECR Storage | ✅ 500MB free, then $0.10/GB | ~$1/mo |
| S3 (Terraform state) | ✅ 5GB free | ~$0 |
| ALB | ✅ 750hrs/mo for 12 months | $0 |

> ⚠️ **IMPORTANT:** Always run `./scripts/stop-env.sh dev` at the end of every session.
> This scales EKS nodes to 0 and stops RDS — saving ~$2/day in compute costs.
> The EKS control plane (~$3.30/day) cannot be stopped without destroying it.
> **Target: keep total AWS spend under $50 for the entire course.**

---

## 5. Prerequisites — Install Everything

Open your WSL2 Ubuntu terminal and run these commands.

### Verify WSL2 is running Ubuntu

```bash
cat /etc/os-release
# Should show Ubuntu
```

### Install Terraform

```bash
wget https://releases.hashicorp.com/terraform/1.10.0/terraform_1.10.0_linux_amd64.zip
unzip terraform_1.10.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/
terraform --version
# Should show: Terraform v1.10.0
```

### Install AWS CLI v2

```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
aws --version
# Should show: aws-cli/2.x.x
```

### Install kubectl

```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
kubectl version --client
```

### Install Helm

```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version
```

### Install ArgoCD CLI

```bash
curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x /usr/local/bin/argocd
argocd version --client
```

### Install yq (for YAML editing in CI)

```bash
pip install yq --break-system-packages
yq --version
```

### Verify all tools

```bash
terraform --version
aws --version
kubectl version --client
helm version
argocd version --client
docker --version
git --version
```

---

## 6. Configure AWS

### Create an AWS IAM User (if you don't have one)

1. Log in to [AWS Console](https://console.aws.amazon.com)
2. Go to IAM → Users → Create User
3. Attach policy: `AdministratorAccess` (for learning — restrict in production)
4. Create Access Key → Download the CSV

### Configure AWS CLI Profile

```bash
aws configure --profile voh-admin
# AWS Access Key ID: (paste from CSV)
# AWS Secret Access Key: (paste from CSV)
# Default region name: eu-central-1
# Default output format: json
```

### Verify AWS access

```bash
aws sts get-caller-identity --profile voh-admin
# Should return your account ID, user ARN
```

### Set profile for your session

```bash
export AWS_PROFILE=voh-admin
export AWS_DEFAULT_REGION=eu-central-1
```

> Add these exports to your `~/.bashrc` so they persist across sessions:
> ```bash
> echo 'export AWS_PROFILE=voh-admin' >> ~/.bashrc
> echo 'export AWS_DEFAULT_REGION=eu-central-1' >> ~/.bashrc
> source ~/.bashrc
> ```

---

## 7. Clone the Repos

```bash
# Clone the platform repo (this is where you work)
git clone https://github.com/stephcloud/petclinic-platform.git
cd petclinic-platform

# Clone the app repo (read-only reference)
git clone https://github.com/stephcloud/spring-petclinic-microservices.git
```

---

## 8. Set Up Your AI Coding Agent (Kimchi)

Kimchi is a free AI coding agent that helps you write Terraform, Kubernetes manifests, Helm charts, and more. It uses open-source models and gives you $250 in free credits.

### Install Kimchi

```bash
curl -fsSL https://github.com/getkimchi/kimchi/releases/latest/download/install.sh | bash
```

### First-time setup

```bash
kimchi setup
# Follow the prompts
# Select: "Use a Kimchi API key"
# Get your API key from: https://app.kimchi.dev/api-keys
```

### Create the AGENTS.md file

The `AGENTS.md` file tells Kimchi everything about your project — conventions, rules, security requirements. Create it at the project root:

```bash
cd ~/petclinic-platform
nano AGENTS.md
```

Paste the following content:

```markdown
# Petclinic Platform — Agent Instructions

## Two-Repo Architecture (CRITICAL — Read First)

This project uses a two-repo GitOps pattern:

| Repo | URL | Purpose | Can Agent Modify? |
|------|-----|---------|-------------------|
| petclinic-platform | github.com/stephcloud/petclinic-platform | Infrastructure | ✅ YES |
| spring-petclinic-microservices | github.com/stephcloud/spring-petclinic-microservices | App source code | ❌ READ-ONLY |

### How the two repos work together

App repo CI builds images → pushes to ECR → fires dispatch to platform repo
Platform repo updates helm-values/ → ArgoCD detects → deploys to EKS

## Directory Layout

terraform/environments/{dev,prod}/
terraform/modules/{vpc,eks,ecr,rds,dns,secrets,observability,karpenter}/
helm/petclinic-service/
helm-values/
k8s/base/
k8s/argocd/install/
k8s/argocd/applications/{dev,prod}/
.github/workflows/
scripts/
docs/

## Technical Reference

Read docs/technical-spec.md before implementing any story.
Work backlog: docs/jira-backlog.md (17 epics).
Dependency chain: E-0 → E-1 → VPC → EKS → K8s → Helm → ArgoCD

## Terraform Conventions

- Provider: AWS ~> 5.0, region eu-central-1
- State: S3 + DynamoDB, key: petclinic/{env}/terraform.tfstate
- Naming: petclinic-{env}-{resource}
- Tags: Project=petclinic, Environment={dev|prod}, ManagedBy=terraform
- Files per module: main.tf, variables.tf, outputs.tf, versions.tf
- Never hardcode secrets. Use sensitive = true for secret outputs.
- Run terraform fmt before committing. Run terraform validate after edits.

### Terraform Workflow
terraform fmt -recursive
terraform validate
terraform plan -out plan.out
terraform apply plan.out   # NEVER apply without a saved plan

## Kubernetes Conventions

- Namespaces: petclinic-dev, petclinic-prod
- Every resource MUST have labels: app.kubernetes.io/name, part-of=petclinic, managed-by=Helm
- Every Deployment MUST have readinessProbe and livenessProbe on /actuator/health endpoints
- Every container MUST have resource requests AND limits
- Image tags: commit SHA only, never latest
- Secrets: ExternalSecret CRs only, never in YAML

## Helm Conventions

- Single generic chart in helm/petclinic-service/ shared by all 8 services
- Per-service config in helm-values/{service}.yaml
- Per-env config in helm-values/{dev,prod}.yaml
- Validate: helm template + helm lint before committing
- ECR registry dev: 533267262133.dkr.ecr.eu-central-1.amazonaws.com/petclinic-dev
- ECR registry prod: 533267262133.dkr.ecr.eu-central-1.amazonaws.com/petclinic-prod

## ArgoCD Conventions

- CI pushes images. ArgoCD deploys. GitHub Actions NEVER runs kubectl apply.
- Dev: auto-sync (prune + self-heal)
- Prod: manual sync required
- 16 Applications total: 8 services x 2 environments

## CI/CD Pipeline Conventions

- CI in app repo. CD via ArgoCD watching platform repo.
- AWS auth: OIDC federation, never static credentials
- Image tags: commit SHA (7 chars), never latest
- Trivy scan after build, fail on CRITICAL CVEs
- GitHub Secrets: AWS_ROLE_ARN, AWS_REGION, AWS_ACCOUNT_ID, PLATFORM_REPO_TOKEN

## Security Rules (NON-NEGOTIABLE)

1. No secrets in code — use AWS Secrets Manager + External Secrets Operator
2. No public S3 buckets
3. No open security groups — no 0.0.0.0/0 except ALB on 80/443
4. Encryption everywhere — RDS, S3, EBS
5. Least privilege IAM — never */*
6. No terraform destroy without approval
7. No *.tfvars or .env files committed

## AWS Environment Details

| Setting | Dev | Prod |
|---------|-----|------|
| Region | eu-central-1 | eu-central-1 |
| Namespace | petclinic-dev | petclinic-prod |
| EKS nodes | 2x t4g.small ARM | 2x t4g.small ARM |
| RDS | db.t4g.micro | db.t4g.micro |
| Deploy | ArgoCD auto-sync | ArgoCD manual sync |

## Application Services (8 total)

| Service | Port | MySQL | Notes |
|---------|------|-------|-------|
| config-server | 8888 | No | Starts FIRST |
| discovery-server | 8761 | No | Starts SECOND |
| api-gateway | 8080 | No | Public-facing |
| customers-service | 8081 | Yes | |
| visits-service | 8082 | Yes | Deploy AFTER customers |
| vets-service | 8083 | Yes | Needs production profile |
| genai-service | 8084 | Optional | Needs OPENAI_API_KEY |
| admin-server | 9090 | No | |

## Safety Rules for Agent Actions

- NEVER run terraform destroy
- NEVER run rm -rf on terraform/, k8s/, helm/, .github/
- NEVER run terraform apply without a saved plan.out
- NEVER commit .env, .tfvars, .pem, .key files
- ALWAYS run terraform validate after editing .tf files
- ALWAYS run helm template to validate Helm changes

## Cost Reminder

Run ./scripts/stop-env.sh dev at end of every session.
EKS control plane costs ~$3.30/day even when idle.
```

Save and close (`Ctrl+X`, `Y`, `Enter` in nano).

### Set up Kimchi safety hooks

Kimchi hooks prevent dangerous commands from running. Your repo already has hooks written for Claude Code — copy them to the Kimchi hooks directory:

```bash
cd ~/petclinic-platform

# Create Kimchi hooks directory
mkdir -p .kimchi/hooks/bash

# Copy hooks from Claude's directory to Kimchi's
cp .claude/hooks/block-destroy.sh .kimchi/hooks/bash/
cp .claude/hooks/block-dangerous-rm.sh .kimchi/hooks/bash/
cp .claude/hooks/block-secret-commit.sh .kimchi/hooks/bash/
cp .claude/hooks/warn-apply-without-plan.sh .kimchi/hooks/bash/
cp .claude/hooks/suggest-validate.sh .kimchi/hooks/bash/
cp .claude/hooks/block-mcp-destroy.sh .kimchi/hooks/bash/
```

### Enable the hooks in Kimchi

```bash
kimchi resources enable hooks.block-destroy
kimchi resources enable hooks.block-dangerous-rm
kimchi resources enable hooks.block-secret-commit
kimchi resources enable hooks.warn-apply-without-plan
kimchi resources enable hooks.suggest-validate
kimchi resources enable hooks.block-mcp-destroy
```

### What each hook does

| Hook | Type | Protects Against |
|------|------|-----------------|
| block-destroy.sh | Block | `terraform destroy` accidentally deleting real infrastructure |
| block-dangerous-rm.sh | Block | `rm -rf` on critical folders (terraform/, k8s/, helm/) |
| block-secret-commit.sh | Block | Committing `.env`, `.tfvars`, `.pem`, `.key` files |
| warn-apply-without-plan.sh | Warn | `terraform apply` without a saved plan file |
| suggest-validate.sh | Info | Reminds you to validate after editing .tf files |
| block-mcp-destroy.sh | Block | `destroy` commands via MCP Terraform tools |

### Verify your setup

```bash
ls -la AGENTS.md
ls .kimchi/hooks/bash/
ls -la
```

Expected output:
```
AGENTS.md       ← your project instructions for Kimchi
CLAUDE.md       ← original Claude Code file (keep it, Kimchi reads both)
.kimchi/        ← Kimchi config and hooks
.claude/        ← original Claude Code config
.mcp.json       ← MCP server config
docs/
scripts/
```

### Launch Kimchi for the first time

```bash
cd ~/petclinic-platform
kimchi --plan
```

`--plan` mode is read-only — Kimchi explores your project without executing anything. No credits wasted. Use this first to see how Kimchi understands your codebase.

### Kimchi quick reference

| Command | What it does |
|---------|-------------|
| `kimchi` | Start normal chat session |
| `kimchi --plan` | Read-only planning mode (safe, saves credits) |
| `kimchi --ferment "task"` | Autonomous mode — plan once, runs itself |
| `/ferment auto` | Keep running until done |
| `/ferment pause` | Pause the ferment |
| `/ferment exit` | Leave ferment mode without deleting |
| `Ctrl+C` | Exit Kimchi |

> **Credit saving tips:**
> - Always start with `kimchi --plan` on a new task
> - Be specific in your prompts — vague = more back-and-forth = more tokens
> - Use `/ferment` only when you're confident in the task description

---

## 9. Phase 0 — Bootstrap AWS State Backend

Before any Terraform can run, you need an S3 bucket and DynamoDB table to store Terraform state. This is a one-time manual setup.

```bash
cd ~/petclinic-platform

# Set your account ID
export AWS_PROFILE=voh-admin
export AWS_DEFAULT_REGION=eu-central-1
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "Your Account ID: $ACCOUNT_ID"

# Run the bootstrap script
bash scripts/bootstrap-state.sh
```

If the bootstrap script doesn't exist yet, run this manually:

```bash
REGION=eu-central-1
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET_NAME="petclinic-terraform-state-${ACCOUNT_ID}"

# Create S3 bucket
aws s3 mb s3://${BUCKET_NAME} --region ${REGION}

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket ${BUCKET_NAME} \
  --versioning-configuration Status=Enabled

# Block public access
aws s3api put-public-access-block \
  --bucket ${BUCKET_NAME} \
  --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket ${BUCKET_NAME} \
  --server-side-encryption-configuration \
    '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name petclinic-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region ${REGION}

echo "✅ Bootstrap complete!"
echo "State bucket: ${BUCKET_NAME}"
echo "Lock table: petclinic-terraform-locks"
```

Write down your bucket name — you will need it in every Terraform backend config.

---

## 10. Phase 1 — Terraform VPC + EKS

Now use Kimchi to build the Terraform infrastructure.

```bash
cd ~/petclinic-platform
kimchi
```

Use these prompts **one at a time**. Wait for each file to be created before the next prompt.

**Prompt 1 — Scaffold Terraform structure:**
```
Create the Terraform directory structure for this project following the
conventions in AGENTS.md. Create terraform/environments/dev/ and
terraform/environments/prod/ each with main.tf, variables.tf, outputs.tf,
backend.tf, and versions.tf. Create terraform/modules/ with subdirectories:
vpc, eks, ecr, rds, dns, secrets, karpenter. Each module dir needs empty
main.tf, variables.tf, outputs.tf, versions.tf. Do not write resource code yet.
```

**Prompt 2 — VPC module:**
```
Write the VPC module in terraform/modules/vpc/.
All-public subnet design (no NAT Gateway — cost optimization for learning).
2 AZs (eu-central-1a, eu-central-1b), public subnets only.
VPC CIDR: variable. Enable DNS support and DNS hostnames.
Internet Gateway attached. Single route table: 0.0.0.0/0 → IGW.
Subnet tags for EKS: kubernetes.io/cluster/petclinic-{env}=shared,
kubernetes.io/role/elb=1. Tags: Project=petclinic, Environment, ManagedBy=terraform.
Outputs: vpc_id, public_subnet_ids, eks_cluster_sg_id, eks_node_sg_id,
rds_sg_id, alb_sg_id. Include all 4 security groups (EKS cluster, EKS node, RDS, ALB).
```

**Prompt 3 — EKS module:**
```
Write the EKS module in terraform/modules/eks/.
Kubernetes version 1.29. Cluster IAM role with AmazonEKSClusterPolicy.
OIDC provider from cluster identity issuer (required for IRSA).
Managed node group: t4g.small (ARM64/Graviton), AL2_ARM_64 AMI,
min=2 max=4 desired=2, disk=20GB. Node IAM role with
AmazonEKSWorkerNodePolicy, AmazonEKS_CNI_Policy, AmazonEC2ContainerRegistryReadOnly.
EKS managed add-ons: coredns, kube-proxy, vpc-cni, aws-ebs-csi-driver (pinned versions).
Outputs: cluster_name, cluster_endpoint, cluster_ca_certificate,
oidc_provider_arn, oidc_provider_url, node_group_name, node_role_arn.
```

**Prompt 4 — Wire dev environment:**
```
Write terraform/environments/dev/main.tf wiring vpc and eks modules together.
VPC CIDR: 10.0.0.0/16, subnets: 10.0.1.0/24 (eu-central-1a), 10.0.2.0/24 (eu-central-1b).
EKS cluster name: petclinic-dev, node group: petclinic-dev-nodes.
S3 backend in backend.tf: bucket=petclinic-terraform-state-{YOUR_ACCOUNT_ID},
key=petclinic/dev/terraform.tfstate, region=eu-central-1,
dynamodb_table=petclinic-terraform-locks. AWS provider version ~> 5.0.
Default tags: Project=petclinic, Environment=dev, ManagedBy=terraform.
```

**Apply dev infrastructure:**
```bash
cd terraform/environments/dev

terraform init
terraform fmt -recursive
terraform validate
terraform plan -out plan.out
# Review the plan carefully before applying
terraform apply plan.out
```

**Connect kubectl to your cluster:**
```bash
aws eks update-kubeconfig --name petclinic-dev --region eu-central-1
kubectl get nodes
# Should show 2 Ready nodes
```

---

## 11. Phase 2 — Terraform RDS MySQL

```
Write the RDS module in terraform/modules/rds/.
MySQL 8.0, db.t4g.micro (free tier), single-AZ (Multi-AZ=false for cost).
20GB gp2 storage, autoscaling max 20GB.
Encryption at rest with AWS default KMS key.
Backup retention: 7 days. Skip final snapshot: true.
DB parameter group: character_set_server=utf8mb4.
Generate master password with random_password (16+ chars).
Store credentials in AWS Secrets Manager as JSON:
secret name petclinic/{env}/rds-credentials with username and password keys.
RDS security group: allow port 3306 from EKS node SG only.
Outputs: endpoint, port, db_instance_id, secret_arn.
Add RDS module to terraform/environments/dev/main.tf.
```

```bash
terraform plan -out plan.out
terraform apply plan.out
```

---

## 12. Phase 3 — Container Registry (ECR)

```
Write the ECR module in terraform/modules/ecr/.
Create one ECR private repository per service using aws_ecr_repository.
Services: config-server, discovery-server, api-gateway, customers-service,
visits-service, vets-service, genai-service, admin-server.
Repository names: petclinic-{env}/{service-name}.
Scan-on-push enabled. Tag mutability: MUTABLE for dev, IMMUTABLE for prod.
Lifecycle policy: keep last 10 images, expire untagged after 7 days.
Outputs: map of service_name to repository_url and repository_arn.
Add ECR module to terraform/environments/dev/main.tf and apply.
```

### Build and push initial Docker images

```bash
cd ~/spring-petclinic-microservices

# Build all 8 images for ARM64 (required for Graviton t4g nodes)
./mvnw clean install -P buildDocker -Dcontainer.platform="linux/arm64"

# Log in to ECR
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws ecr get-login-password --region eu-central-1 | \
  docker login --username AWS \
  --password-stdin ${ACCOUNT_ID}.dkr.ecr.eu-central-1.amazonaws.com

# Push all 8 images
SERVICES="config-server discovery-server api-gateway customers-service visits-service vets-service genai-service admin-server"
for svc in $SERVICES; do
  docker tag springcommunity/spring-petclinic-${svc}:latest \
    ${ACCOUNT_ID}.dkr.ecr.eu-central-1.amazonaws.com/petclinic-dev/${svc}:v1.0.0
  docker push ${ACCOUNT_ID}.dkr.ecr.eu-central-1.amazonaws.com/petclinic-dev/${svc}:v1.0.0
  echo "✅ Pushed ${svc}"
done
```

---

## 13. Phase 4 — Secrets Management

```
Create the External Secrets Operator setup:
1. Write terraform/modules/secrets/ for non-RDS secrets
   (openai-api-key at petclinic/{env}/openai-api-key)
2. Create IRSA role for ESO with secretsmanager:GetSecretValue and
   secretsmanager:DescribeSecret on arn:aws:secretsmanager:*:*:secret:petclinic/*
3. Install ESO on EKS via kubectl apply
4. Create ClusterSecretStore manifest pointing to AWS Secrets Manager
5. Create ExternalSecret manifests:
   - k8s/base/external-secrets/rds-credentials.yaml
   - k8s/base/external-secrets/openai-api-key.yaml
Follow the conventions in AGENTS.md.
```

---

## 14. Phase 5 — Kubernetes Base Manifests

```
Create Kubernetes base manifests for all 8 petclinic services in k8s/base/.
Follow conventions in AGENTS.md exactly:
- Namespaces: petclinic-dev and petclinic-prod in k8s/base/namespaces.yaml
- Every Deployment: readinessProbe and livenessProbe on /actuator/health endpoints
- Every container: resource requests cpu=100m/memory=128Mi, limits cpu=500m/memory=512Mi
  (api-gateway: cpu=200m/1000m — handles more traffic)
- Image tags: placeholder SHA (CI will fill these in)
- Startup order enforced via init containers:
  config-server: no init containers
  discovery-server: wait for config-server:8888
  all others: wait for config-server:8888 AND discovery-server:8761
- DB services (customers, visits, vets): SPRING_PROFILES_ACTIVE=docker,mysql
  SPRING_DATASOURCE_URL from ConfigMap, credentials from ESO ExternalSecret
- vets-service: SPRING_PROFILES_ACTIVE=docker,mysql,production (Caffeine cache)
- genai-service: OPENAI_API_KEY from ESO ExternalSecret
- Security context: runAsNonRoot=true, runAsUser=1000
```

---

## 15. Phase 6 — Helm Charts

```
Create a generic Helm chart at helm/petclinic-service/ shared by all 8 services.
Templates needed: deployment.yaml, service.yaml, configmap.yaml,
serviceaccount.yaml, hpa.yaml (conditional), pdb.yaml (conditional), _helpers.tpl.
Use Go template syntax. Conditional resources with {{- if .Values.x.enabled }}.
Never hardcode environment-specific values in templates.

Then create per-service values files in helm-values/:
config-server.yaml, discovery-server.yaml, api-gateway.yaml,
customers-service.yaml, visits-service.yaml, vets-service.yaml,
genai-service.yaml, admin-server.yaml.

And environment values files:
helm-values/dev.yaml — replicas=1, HPA disabled, namespace petclinic-dev
helm-values/prod.yaml — replicas=2, HPA enabled, PDB enabled, namespace petclinic-prod

Validate with:
helm lint helm/petclinic-service/
helm template petclinic helm/petclinic-service/ \
  -f helm-values/config-server.yaml \
  -f helm-values/dev.yaml
```

---

## 16. Phase 7 — ArgoCD GitOps

### Install ArgoCD on EKS

```bash
kubectl create namespace argocd
kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
kubectl wait --for=condition=available deployment/argocd-server \
  -n argocd --timeout=300s

# Get the initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo

# Access ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Open https://localhost:8080 (accept the self-signed cert)
# Username: admin, Password: from above command
```

### Create ArgoCD Application manifests with Kimchi

```
Create ArgoCD Application CRDs for all 8 services in both environments.

Dev applications (k8s/argocd/applications/dev/):
- One Application per service
- Source: this GitHub repo (petclinic-platform), path=helm/petclinic-service
- Values files: helm-values/{service}.yaml + helm-values/dev.yaml
- Destination namespace: petclinic-dev
- Sync policy: automated with prune=true and selfHeal=true

Prod applications (k8s/argocd/applications/prod/):
- Same structure but NO automated sync policy (manual only)
- Destination namespace: petclinic-prod

Also create ArgoCD RBAC config:
- Admin: full access
- Developer: view all, sync dev only
```

### Apply ArgoCD applications

```bash
kubectl apply -f k8s/argocd/applications/dev/
argocd app list
# All 8 apps should appear
```

---

## 17. Phase 8 — GitHub Actions CI Pipeline

### Configure OIDC Federation (no static AWS keys)

```bash
# Get your GitHub org/repo
GITHUB_ORG="stephcloud"
APP_REPO="spring-petclinic-microservices"
PLATFORM_REPO="petclinic-platform"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
```

Use Kimchi to create the OIDC IAM role:

```
Create Terraform resources for GitHub Actions OIDC federation in
terraform/environments/dev/github-actions.tf:
- OIDC provider: token.actions.githubusercontent.com
- IAM role: petclinic-github-actions-role
- Trust policy: repo:stephcloud/spring-petclinic-microservices:ref:refs/heads/main
- Permissions: ECR push only (ecr:GetAuthorizationToken,
  ecr:BatchCheckLayerAvailability, ecr:PutImage, ecr:InitiateLayerUpload,
  ecr:UploadLayerPart, ecr:CompleteLayerUpload)
- Also allow: repository_dispatch to platform repo
- Output: role ARN
```

### Create GitHub Secrets

In your **app repo** (`spring-petclinic-microservices`) on GitHub:
- Go to Settings → Secrets and variables → Actions
- Add: `AWS_ROLE_ARN` (the OIDC role ARN from Terraform output)
- Add: `AWS_REGION` = `eu-central-1`
- Add: `AWS_ACCOUNT_ID` (your AWS account ID)
- Add: `PLATFORM_REPO_TOKEN` (GitHub PAT with repo write access to platform repo)

### Create CI workflows with Kimchi

**In the app repo** (use Kimchi from spring-petclinic-microservices directory):

```
Create .github/workflows/build-push.yml:
- Trigger: push to main branch
- Use dorny/paths-filter to detect which of the 8 service directories changed
- Matrix build: only services that changed (not all 8 every time)
- Steps: checkout, JDK 17, Docker Buildx + QEMU (for ARM64)
- AWS auth via OIDC (aws-actions/configure-aws-credentials with role-to-assume)
- ECR login via aws-actions/amazon-ecr-login
- Build: --platform linux/arm64 for each changed service
- Trivy scan: fail on CRITICAL CVEs, save results as artifact
- Tag with 7-char commit SHA
- Push to ECR: {account}.dkr.ecr.eu-central-1.amazonaws.com/petclinic-dev/{service}:{sha}
- After all pushes: fire repository_dispatch event to petclinic-platform repo
  with payload: {sha: github.sha[:7], services: [list of changed services]}
```

**In the platform repo** (use Kimchi from petclinic-platform directory):

```
Create .github/workflows/update-image-tags.yml:
- Trigger: repository_dispatch with type app-image-built
- Checkout platform repo
- For each service in the dispatch payload:
  Use yq to update image.tag in helm-values/{service}.yaml to the new SHA
- Git commit: "ci: update image tags to {sha} ({service-list})"
- Git push
- ArgoCD will detect the change and auto-sync dev
```

---

## 18. Phase 9 — Prometheus + Grafana Monitoring

```
Deploy the observability stack using Kimchi:

1. Install kube-prometheus-stack Helm chart to monitoring namespace
   with values file at helm-values/prometheus-stack.yaml
2. Configure ServiceMonitor CRDs to scrape all 8 petclinic services
   at /actuator/prometheus on their respective ports
3. Create Grafana dashboards for:
   - Service overview (all 8 services: RPS, error rate, latency)
   - Per-service dashboard (p95/p99 latency, JVM metrics)
4. Create Prometheus alert rules:
   - ServiceDown (up == 0 for 1m, critical)
   - HighErrorRate (>5% 5xx over 5m, warning)
   - HighLatency (p95 > 500ms over 5m, warning)
   - PodRestartLoop (>3 restarts in 15m, critical)
5. Deploy Loki + FluentBit for log aggregation
6. Deploy Alertmanager with email/Slack notifications
7. Deploy Zipkin for distributed tracing (port 9411)
```

### Access monitoring tools

```bash
# Grafana
kubectl port-forward svc/prometheus-grafana -n monitoring 3000:80
# Open http://localhost:3000
# Username: admin, Password: (from grafana secret)

# Prometheus
kubectl port-forward svc/prometheus-kube-prometheus-prometheus -n monitoring 9090:9090
# Open http://localhost:9090

# Zipkin
kubectl port-forward svc/zipkin -n tracing 9411:9411
# Open http://localhost:9411
```

---

## 19. Daily Workflow

### Starting a session

```bash
cd ~/petclinic-platform

# 1. Check what's running and estimated cost
./scripts/env-status.sh dev

# 2. Start the environment (scale nodes back up, start RDS)
./scripts/start-env.sh dev
# Wait 3-8 minutes for nodes to be Ready

# 3. Connect kubectl
aws eks update-kubeconfig --name petclinic-dev --region eu-central-1

# 4. Verify cluster is healthy
kubectl get nodes
kubectl get pods -n petclinic-dev

# 5. Launch Kimchi
kimchi
```

### Ending a session

```bash
# Inside Kimchi, type exit or press Ctrl+C

# CRITICAL: Stop the environment to save money
./scripts/stop-env.sh dev

# Verify everything is stopped
./scripts/env-status.sh dev
```

### Kimchi session tips

```
# Always start with a plan — free, no execution
kimchi --plan

# For focused tasks, be specific:
"Write terraform/modules/rds/outputs.tf — output endpoint, port, db_instance_id, secret_arn only. No explanation needed."

# Not this:
"Help me with RDS outputs"

# Use ferment for big tasks you understand well:
/ferment "Create all 8 ArgoCD Application manifests for dev environment following AGENTS.md conventions"
```

---

## 20. Troubleshooting

### Kimchi pasting issue in WSL

Right-click in terminal to paste, or use `Shift+Insert`.

### Kimchi OAuth browser login fails

If the browser callback times out, select **"Use a Kimchi API key"** instead:
1. Go to `https://app.kimchi.dev/api-keys`
2. Create a new API key
3. Paste it in the terminal (right-click to paste in WSL)

### terraform apply fails with state lock error

```bash
# Check if a lock file is stuck
aws s3 ls s3://petclinic-terraform-state-{ACCOUNT_ID}/dev/

# Remove stuck lock (only if no other apply is running)
aws s3 rm s3://petclinic-terraform-state-{ACCOUNT_ID}/dev/terraform.tfstate.tflock
```

### EKS nodes not Ready after start-env.sh

```bash
kubectl get nodes
# If still NotReady after 10 minutes:
aws eks describe-nodegroup \
  --cluster-name petclinic-dev \
  --nodegroup-name petclinic-dev-nodes \
  --region eu-central-1
```

### Pod in CrashLoopBackOff

```bash
kubectl logs deployment/{service} -n petclinic-dev --tail=100 --previous
kubectl describe pod -l app.kubernetes.io/name={service} -n petclinic-dev
```

### ArgoCD app stuck in Unknown sync status

```bash
argocd app get {app-name}
argocd app sync {app-name} --force
```

### Services not registering with Eureka

Config Server must be healthy first. Check:
```bash
kubectl logs deployment/config-server -n petclinic-dev --tail=50
# Then check discovery-server
kubectl logs deployment/discovery-server -n petclinic-dev --tail=50
```

### Image pull error from ECR

```bash
# Re-authenticate Docker to ECR
aws ecr get-login-password --region eu-central-1 | \
  docker login --username AWS \
  --password-stdin {ACCOUNT_ID}.dkr.ecr.eu-central-1.amazonaws.com
```

---

## 21. Cost Reference

| Component | Running | Stopped |
|-----------|---------|---------|
| EKS control plane | ~$3.30/day | ~$3.30/day (always on) |
| EC2 nodes (2x t4g.small) | ~$0/day (free trial) | $0 |
| RDS db.t4g.micro | ~$0/day (free tier) | $0 |
| ECR storage | ~$0.05/day | $0.05/day |
| **Total active** | **~$3.35/day** | **~$3.35/day** |

> The EKS control plane is the main cost. If you stop working for more than 3 days,
> run `terraform destroy` to avoid accumulating charges, then rebuild when you return.
> Rebuilding from Terraform takes about 20-30 minutes.

### Destroy and rebuild

```bash
# Destroy (only when done for multiple days)
cd terraform/environments/dev
terraform destroy

# Rebuild later
terraform apply plan.out
aws eks update-kubeconfig --name petclinic-dev --region eu-central-1
kubectl apply -f k8s/argocd/applications/dev/
```

---

## Resources

- [Kimchi Docs](https://docs.kimchi.dev)
- [Kimchi GitHub](https://github.com/getkimchi/kimchi)
- [Kimchi Discord](https://discord.com/invite/getkimchi)
- [AWS EKS Docs](https://docs.aws.amazon.com/eks/)
- [ArgoCD Docs](https://argo-cd.readthedocs.io)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Spring Petclinic Microservices](https://github.com/spring-petclinic/spring-petclinic-microservices)

---

*Built as part of the DMI (DevOps Micro Internship) Cohort 2 program.*
