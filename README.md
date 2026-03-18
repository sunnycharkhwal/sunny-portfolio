# Sunny Portfolio — Full DevSecOps Pipeline

## Stack at a glance

| Layer              | Tool                        | What it does                                      |
|--------------------|-----------------------------|---------------------------------------------------|
| Source control     | GitHub                      | Hosts code, triggers Jenkins on push              |
| CI                 | Jenkins                     | Build → scan → package → push                     |
| Code quality       | SonarQube                   | Static analysis with quality gate                 |
| Dependency scan    | OWASP Dependency-Check      | CVE scan on npm packages                          |
| Image/FS scan      | Trivy                       | Filesystem and Docker image vulnerability scan    |
| Container registry | AWS ECR                     | Private Docker image storage                      |
| CD                 | ArgoCD                      | GitOps — watches Git, syncs Helm chart to EKS     |
| Orchestration      | AWS EKS (Kubernetes)        | Runs containerised workloads                      |
| Packaging          | Helm                        | Templates all Kubernetes manifests                |
| Caching            | AWS ElastiCache (Redis)     | Response caching layer                            |
| Monitoring         | Prometheus + Grafana (Helm) | Metrics collection and dashboards                 |
| SSL                | AWS ACM                     | Free managed TLS certificate                      |
| DNS                | GoDaddy                     | sunnycharkhwalcloud.shop → ALB                    |
| Infrastructure     | Terraform                   | All AWS resources provisioned as code             |

---

## File structure

```
portfolio-devsecops/
├── Dockerfile                          ← copy to root of React repo
├── nginx.conf                          ← copy to root of React repo
├── .gitignore
├── terraform/
│   ├── bootstrap/
│   │   └── main.tf                     ← run ONCE first (creates S3 + DynamoDB)
│   ├── main.tf                         ← VPC, EKS, ECR, Redis, ACM, ALB controller
│   ├── variables.tf
│   └── outputs.tf
├── jenkins/
│   └── Jenkinsfile                     ← 9-stage CI pipeline
├── argocd/
│   └── application.yaml                ← ArgoCD GitOps app definition
├── helm/
│   ├── portfolio/
│   │   ├── Chart.yaml
│   │   ├── values.yaml                 ← EDIT: paste ECR URL, ACM ARN, Redis endpoint
│   │   └── templates/
│   │       ├── _helpers.tpl
│   │       ├── deployment.yaml
│   │       ├── service.yaml
│   │       ├── ingress.yaml
│   │       └── hpa.yaml
│   └── monitoring/
│       └── values.yaml                 ← EDIT: paste ACM ARN, change Grafana password
└── scripts/
    ├── setup.sh                        ← run once after terraform apply
    └── destroy.sh                      ← tear everything down safely
```

---

## Prerequisites — install on your Mac

```bash
# Homebrew packages
brew tap hashicorp/tap
brew install \
  hashicorp/tap/terraform \
  awscli \
  kubectl \
  helm \
  git

# Verify versions
terraform version   # >= 1.6.0
aws --version
kubectl version --client
helm version
```

---

## Phase 1 — AWS credentials

### 1a — Create IAM user

1. AWS Console → IAM → Users → Create user
2. Name: `terraform-deployer`
3. Attach policies directly:
   - `AdministratorAccess`
   (or scoped: `AmazonEKSFullAccess`, `AmazonEC2FullAccess`, `AmazonECR...`, `ElastiCache...`, `AmazonS3FullAccess`, `IAMFullAccess`, `AmazonDynamoDBFullAccess`, `AWSCertificateManagerFullAccess`)
4. Security credentials tab → Create access key → CLI → copy both values

### 1b — Configure AWS CLI

```bash
aws configure
# AWS Access Key ID     : paste key
# AWS Secret Access Key : paste secret
# Default region        : ap-south-1
# Default output format : json

# Verify
aws sts get-caller-identity
```

---

## Phase 2 — Terraform: create S3 state backend (once only)

```bash
cd terraform/bootstrap
terraform init
terraform apply
# Type 'yes' when prompted
```

This creates `sunny-portfolio-tfstate` S3 bucket and `sunny-portfolio-tf-lock` DynamoDB table.

---

## Phase 3 — Terraform: provision all AWS infrastructure

```bash
cd terraform
terraform init
terraform plan
terraform apply
# Type 'yes' when prompted
# Takes approximately 15–20 minutes
```

When complete, copy the five output values — you need all of them:

```
ecr_repository_url       = "123456789.dkr.ecr.ap-south-1.amazonaws.com/sunny-portfolio"
redis_endpoint           = "sunny-portfolio-redis.abc.ng.0001.aps1.cache.amazonaws.com"
acm_certificate_arn      = "arn:aws:acm:ap-south-1:123456789:certificate/xxxxxxxx"
acm_dns_validation_records = {
  "sunnycharkhwalcloud.shop" = {
    name  = "_abc123.sunnycharkhwalcloud.shop."
    type  = "CNAME"
    value = "_def456.acm-validations.aws."
  }
  ...
}
kubeconfig_command = "aws eks update-kubeconfig --region ap-south-1 --name sunny-portfolio"
```

---

## Phase 4 — GoDaddy DNS

Log in to GoDaddy → My Products → sunnycharkhwalcloud.shop → DNS.

### 4a — Validate ACM certificate (CNAME records)

From the `acm_dns_validation_records` output, add one CNAME per domain:

| Type  | Name (strip trailing dot) | Value (strip trailing dot)     |
|-------|---------------------------|--------------------------------|
| CNAME | `_abc123`                 | `_def456.acm-validations.aws`  |
| CNAME | `_abc123.www`             | `_def456.acm-validations.aws`  |

Wait for ACM status to change to **Issued** in the AWS Console (5–30 minutes).

### 4b — Point domain to ALB (do this after running setup.sh in Phase 6)

After `scripts/setup.sh` prints the ALB DNS name:

| Type  | Name | Value                                              |
|-------|------|----------------------------------------------------|
| CNAME | `@`  | `k8s-xxxxxxxx.ap-south-1.elb.amazonaws.com`       |
| CNAME | `www`| `k8s-xxxxxxxx.ap-south-1.elb.amazonaws.com`       |

---

## Phase 5 — Fill in the three config files

### 5a — helm/portfolio/values.yaml

Open the file and fill in the three `# EDIT` fields:

```yaml
image:
  repository: "123456789.dkr.ecr.ap-south-1.amazonaws.com/sunny-portfolio"

ingress:
  annotations:
    alb.ingress.kubernetes.io/certificate-arn: "arn:aws:acm:ap-south-1:123456789:certificate/xxxxxxxx"

redis:
  externalEndpoint: "sunny-portfolio-redis.abc.ng.0001.aps1.cache.amazonaws.com"
```

### 5b — helm/monitoring/values.yaml

```yaml
grafana:
  adminPassword: "YourStrongPasswordHere"
  ingress:
    annotations:
      alb.ingress.kubernetes.io/certificate-arn: "arn:aws:acm:ap-south-1:123456789:certificate/xxxxxxxx"
```

### 5c — argocd/application.yaml

```yaml
source:
  repoURL: https://github.com/YOUR_GITHUB_USERNAME/sunny-portfolio.git
```

---

## Phase 6 — Bootstrap the cluster

```bash
cd portfolio-devsecops
chmod +x scripts/setup.sh
./scripts/setup.sh
```

This installs ArgoCD, Prometheus, Grafana, applies the ArgoCD Application manifest, and prints the ALB DNS name you need for GoDaddy Phase 4b.

---

## Phase 7 — Set up Jenkins

### 7a — Install Jenkins

**Option A — Docker (quickest)**
```bash
docker run -d \
  --name jenkins \
  --restart unless-stopped \
  -p 8080:8080 \
  -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  jenkins/jenkins:lts

# Get initial admin password
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
# Open: http://localhost:8080
```

**Option B — EC2 (recommended for persistent use)**
```bash
# On an Ubuntu EC2 t3.small with the same security group (port 8080 open)
sudo apt update
sudo apt install -y openjdk-17-jdk
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key \
  | sudo tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian-stable binary/" \
  | sudo tee /etc/apt/sources.list.d/jenkins.list
sudo apt update && sudo apt install -y jenkins
sudo systemctl enable jenkins && sudo systemctl start jenkins
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

### 7b — Install tools on the Jenkins server

```bash
# Docker (if not using Docker-in-Docker)
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins

# Trivy
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh \
  | sudo sh -s -- -b /usr/local/bin

# OWASP Dependency-Check
wget -q https://github.com/jeremylong/DependencyCheck/releases/download/v9.0.7/dependency-check-9.0.7-release.zip
unzip -q dependency-check-9.0.7-release.zip -d /opt/
sudo ln -sf /opt/dependency-check/bin/dependency-check.sh /usr/local/bin/dependency-check

# SonarQube Scanner
wget -q https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-5.0.1.3006-linux.zip
unzip -q sonar-scanner-cli-*.zip -d /opt/
sudo ln -sf /opt/sonar-scanner-5.0.1.3006-linux/bin/sonar-scanner /usr/local/bin/sonar-scanner

# Node.js (needed to build React)
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip
unzip awscliv2.zip && sudo ./aws/install
```

### 7c — Install Jenkins plugins

Manage Jenkins → Plugins → Available → Install:
- `Pipeline`
- `Git`
- `Docker Pipeline`
- `Pipeline: AWS Steps` (pipeline-aws)
- `SonarQube Scanner`
- `OWASP Dependency-Check`
- `HTML Publisher`
- `SSH Agent`
- `Credentials Binding`
- `Timestamper`

### 7d — Add Jenkins credentials

Manage Jenkins → Credentials → (global) → Add credential:

| ID                | Type                        | Value                                                    |
|-------------------|-----------------------------|----------------------------------------------------------|
| `ECR_REPO_URL`    | Secret text                 | Your ECR URL from terraform output                       |
| `aws-credentials` | AWS Credentials             | IAM access key ID + secret                               |
| `SONAR_HOST_URL`  | Secret text                 | `http://localhost:9000` (or your SonarQube server URL)   |
| `SONAR_TOKEN`     | Secret text                 | Token generated in SonarQube UI                          |
| `github-ssh`      | SSH Username with private key | Your GitHub SSH private key                             |
| `HELM_REPO_URL`   | Secret text                 | `git@github.com:YOUR_USERNAME/sunny-portfolio.git`       |

### 7e — Configure SonarQube server in Jenkins

Manage Jenkins → System → SonarQube servers → Add SonarQube:
- Name: `SonarQube`
- Server URL: `http://localhost:9000`
- Token: select the `SONAR_TOKEN` credential

### 7f — Create Jenkins pipeline job

1. New Item → name: `sunny-portfolio` → Pipeline → OK
2. Pipeline section:
   - Definition: `Pipeline script from SCM`
   - SCM: `Git`
   - Repository URL: `https://github.com/YOUR_USERNAME/sunny-portfolio.git`
   - Script Path: `jenkins/Jenkinsfile`
3. Save

---

## Phase 8 — Set up SonarQube

```bash
# Run locally via Docker
docker run -d \
  --name sonarqube \
  --restart unless-stopped \
  -p 9000:9000 \
  sonarqube:community

# Open: http://localhost:9000
# Default: admin / admin → you will be forced to change it
```

In SonarQube UI:
1. Create project → name: `sunny-portfolio` → project key: `sunny-portfolio`
2. Locally → Generate token → copy it → paste into Jenkins credential `SONAR_TOKEN`

---

## Phase 9 — Copy Dockerfile and nginx.conf into your React repo

```bash
cp Dockerfile  ../sunny-portfolio/Dockerfile
cp nginx.conf  ../sunny-portfolio/nginx.conf
```

The Helm chart and Jenkinsfile can live in the same repo as your React code, or in a separate infra repo — ArgoCD watches whichever repo you point it to in `argocd/application.yaml`.

---

## Phase 10 — First deployment

```bash
cd sunny-portfolio
git add .
git commit -m "feat: add DevSecOps pipeline"
git push origin main
```

Jenkins runs all 9 stages automatically:

```
1.  Checkout                  ~10s
2.  Install and Build         ~60s
3.  SonarQube Analysis        ~30s
4.  Quality Gate              ~30s
5.  OWASP Dependency Check    ~3 min
6.  Trivy Filesystem Scan     ~30s
7.  Docker Build              ~90s
8.  Trivy Image Scan          ~30s
9.  Push to ECR               ~30s
10. Update Helm Image Tag     ~20s
     └─ ArgoCD syncs to EKS  ~3 min
```

Total: approximately 12–15 minutes end to end.

---

## Day-to-day usage

Every `git push origin main` triggers the full pipeline automatically.

```bash
# Check pod status
kubectl get pods -n portfolio

# View live logs
kubectl logs -f deployment/sunny-portfolio -n portfolio

# Force ArgoCD to sync immediately (without waiting)
kubectl -n argocd get app sunny-portfolio
argocd app sync sunny-portfolio   # (requires argocd CLI)

# Scale nodes to zero to save cost when not in use
eksctl scale nodegroup \
  --cluster sunny-portfolio \
  --name sunny-portfolio-nodes \
  --nodes 0

# Scale back up
eksctl scale nodegroup \
  --cluster sunny-portfolio \
  --name sunny-portfolio-nodes \
  --nodes 2

# Port-forward ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Open: https://localhost:8080

# Port-forward Grafana (if not using ALB ingress yet)
kubectl port-forward svc/monitoring-grafana -n monitoring 3000:80
# Open: http://localhost:3000
```

---

## Estimated monthly cost (ap-south-1 Mumbai)

| Resource                    | Cost             |
|-----------------------------|------------------|
| EKS control plane           | ~$72/month       |
| 2× t3.medium worker nodes   | ~$60/month       |
| ElastiCache t3.micro (Redis)| ~$12/month       |
| Application Load Balancer   | ~$16/month       |
| NAT Gateway                 | ~$32/month       |
| ECR storage (< 1 GB)        | ~$0.10/month     |
| ACM SSL certificate         | Free             |
| S3 state bucket             | ~$0.10/month     |
| **Total**                   | **~$192/month**  |

> Scale nodes to 0 when not actively using the cluster to reduce cost
> to approximately $110/month (EKS control plane + NAT Gateway still run).
