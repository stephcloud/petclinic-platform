# Petclinic Platform — Agent Instructions

## EXACT VALUES (copy these exactly — never use placeholders)

- **AWS Account:** 720035686687
- **AWS Region:** us-east-1
- **AWS Profile:** chelsea-cloud
- **S3 Bucket:** petclinic-terraform-state-720035686687
- **K8s Version:** 1.32 (never 1.29)
- **Backend:** use_lockfile = true (NOT dynamodb_table)
- **ECR Dev:** 720035686687.dkr.ecr.us-east-1.amazonaws.com/petclinic-dev
- **ECR Prod:** 720035686687.dkr.ecr.us-east-1.amazonaws.com/petclinic-prod
- **Docker Platform:** linux/amd64 (not ARM)
- **Node Type:** t3.medium (x86)

---

## NEVER

- terraform destroy
- rm -rf on terraform/, k8s/, helm/, .github/
- terraform apply without plan.out
- Commit .env, .tfvars, .pem, .key
- Use dynamodb_table (use use_lockfile = true)
- Use Kubernetes 1.29
- Use latest image tag

## ALWAYS

- terraform fmt -recursive
- terraform validate after edits
- helm template before committing
- Use commit SHA for image tags

---

## Two Repos

| Repo | Modify? |
|------|---------|
| petclinic-platform | ✅ YES |
| spring-petclinic-microservices | ❌ NO |

CI builds images in app repo → fires dispatch → platform repo updates helm values → ArgoCD deploys

---

## 8 Services

| Service | Port | MySQL | Notes |
|---------|------|-------|-------|
| config-server | 8888 | No | Start FIRST |
| discovery-server | 8761 | No | Start SECOND |
| api-gateway | 8080 | No | cpu=200m/1000m |
| customers-service | 8081 | Yes | |
| visits-service | 8082 | Yes | After customers |
| vets-service | 8083 | Yes | production profile |
| genai-service | 8084 | Optional | OPENAI_API_KEY |
| admin-server | 9090 | No | |

---

## Terraform
terraform fmt -recursive

terraform validate

terraform plan -out plan.out

terraform apply plan.out

---

## Kubernetes

- Namespaces: petclinic-dev, petclinic-prod
- Labels: app.kubernetes.io/name, part-of=petclinic, managed-by=Helm
- Probes: /actuator/health endpoints required
- Resources: 128Mi request / 512Mi limit per container
- Init containers enforce startup order (config-server → discovery-server → others)

---

## Helm

- Single chart: helm/petclinic-service/
- Per-service: helm-values/{service}.yaml
- Per-env: helm-values/{dev,prod}.yaml
- Validate: helm template + helm lint before commit

---

## Security (NON-NEGOTIABLE)

1. No secrets in code
2. No public S3
3. No open security groups (0.0.0.0/0 only on ALB 80/443)
4. Encrypt RDS, S3, EBS
5. Least privilege IAM
