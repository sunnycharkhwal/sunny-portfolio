# Sunny Portfolio — DevSecOps Infrastructure

## Changing the AWS region

Edit **one file only**:

```
terraform/terraform.tfvars
```

Change `aws_region` to whatever region you want:

```hcl
aws_region = "us-east-1"   # or ap-south-1, eu-west-1, etc.
```

That single change flows automatically to:
- VPC availability zones
- EKS cluster
- ECR repository
- ElastiCache Redis
- ACM certificate
- ALB controller
- All provider configs
- All outputs

> **Note:** The S3 backend block in `terraform/main.tf` and the provider
> in `terraform/bootstrap/main.tf` cannot use variables (Terraform limitation).
> If you change regions you must also update those two lines manually.
> They each have a comment marking exactly where.

---

## File structure

```
infra/
├── terraform/
│   ├── bootstrap/
│   │   └── main.tf              ← run ONCE first
│   ├── main.tf                  ← all AWS resources
│   ├── variables.tf             ← variable declarations
│   ├── outputs.tf               ← prints ECR URL, ACM ARN, etc.
│   └── terraform.tfvars         ← EDIT THIS — region, domain, etc.
├── helm/
│   ├── portfolio/               ← Kubernetes app chart
│   │   ├── Chart.yaml
│   │   ├── values.yaml          ← fill in ECR URL, ACM ARN, Redis endpoint
│   │   └── templates/
│   │       ├── _helpers.tpl
│   │       ├── deployment.yaml
│   │       ├── service.yaml
│   │       ├── ingress.yaml
│   │       └── hpa.yaml
│   └── monitoring/
│       └── values.yaml          ← fill in ACM ARN
├── argocd/
│   └── application.yaml
├── jenkins/
│   └── Jenkinsfile
├── scripts/
│   ├── setup.sh                 ← run once after terraform apply
│   └── destroy.sh               ← tears everything down
├── Dockerfile                   ← copy to root of React repo
└── nginx.conf                   ← copy to root of React repo
```

---

## Deployment order

```bash
# 1. Bootstrap — creates S3 + DynamoDB (once only)
cd infra/terraform/bootstrap
terraform init
terraform apply -auto-approve

# 2. Main infrastructure (15–20 minutes)
cd ../
terraform init
terraform apply -auto-approve

# 3. Save outputs
terraform output

# 4. Fill in values.yaml files with terraform outputs
#    helm/portfolio/values.yaml  → image.repository, certificate-arn, redis.externalEndpoint
#    helm/monitoring/values.yaml → certificate-arn

# 5. Bootstrap cluster
cd ../../
chmod +x scripts/setup.sh
./scripts/setup.sh

# 6. Add CNAME records to GoDaddy (printed by setup.sh)

# 7. Every future deployment
git add . && git commit -m "change" && git push origin main
```

---

## Jenkins credentials required

| ID                | Type            | Value                              |
|-------------------|-----------------|------------------------------------|
| `ECR_REPO_URL`    | Secret text     | terraform output ecr_repository_url |
| `aws-credentials` | AWS Credentials | IAM access key + secret             |
| `SONAR_HOST_URL`  | Secret text     | http://localhost:9000               |
| `SONAR_TOKEN`     | Secret text     | token from SonarQube UI             |
