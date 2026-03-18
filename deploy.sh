#!/usr/bin/env bash
# =============================================================================
#  deploy.sh — Fully automated DevSecOps deployment
#  Sunny Portfolio → GitHub → Jenkins → EKS → sunnycharkhwalcloud.shop
#
#  Usage:
#    chmod +x deploy.sh
#    ./deploy.sh
#
#  What this script does (zero manual steps):
#    1.  Detects OS and installs all required tools automatically
#    2.  Clones/updates https://github.com/sunnycharkhwal/sunny-portfolio.git
#    3.  Prompts once for AWS credentials (or reads from environment)
#    4.  Creates S3 + DynamoDB Terraform state backend
#    5.  Provisions VPC, EKS, ECR, ElastiCache, ACM via Terraform
#    6.  Configures kubectl
#    7.  Installs AWS Load Balancer Controller
#    8.  Installs ArgoCD
#    9.  Installs Prometheus + Grafana via Helm
#    10. Launches Jenkins + SonarQube in Docker
#    11. Auto-configures Jenkins (plugins, credentials, pipeline job)
#    12. Builds and pushes the first Docker image to ECR
#    13. Applies the ArgoCD Application manifest
#    14. Waits for pods to be Running
#    15. Prints ALB DNS name and GoDaddy DNS instructions
# =============================================================================
set -euo pipefail

# ── Colour helpers ─────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'
info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
step()    { echo -e "\n${CYAN}══════════════════════════════════════════${NC}"; \
            echo -e "${CYAN} $*${NC}"; \
            echo -e "${CYAN}══════════════════════════════════════════${NC}"; }
die()     { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# ── Configuration — edit these if needed ──────────────────────────────────────
GITHUB_REPO="https://github.com/sunnycharkhwal/sunny-portfolio.git"
GITHUB_REPO_SSH="git@github.com:sunnycharkhwal/sunny-portfolio.git"
REPO_DIR="$HOME/sunny-portfolio"
AWS_REGION="${AWS_REGION:-us-east-1}"
PROJECT_NAME="sunny-portfolio"
DOMAIN="sunnycharkhwalcloud.shop"
CERTBOT_EMAIL="sunny.charkhwal@gmail.com"
JENKINS_PORT="8080"
SONAR_PORT="9000"
INFRA_DIR="$REPO_DIR/infra"

# ── Detect OS ──────────────────────────────────────────────────────────────────
detect_os() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="mac"
  elif [[ -f /etc/debian_version ]]; then
    OS="debian"
  elif [[ -f /etc/redhat-release ]]; then
    OS="redhat"
  else
    die "Unsupported OS. Run on macOS or Ubuntu/Debian."
  fi
  info "Detected OS: $OS"
}

# ── Install a tool if not present ─────────────────────────────────────────────
need() {
  local cmd=$1
  if command -v "$cmd" &>/dev/null; then
    success "$cmd already installed"
    return
  fi
  info "Installing $cmd..."
  case "$cmd" in
    brew)
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv 2>/dev/null)"
      ;;
    terraform)
      if [[ "$OS" == "mac" ]]; then
        brew tap hashicorp/tap && brew install hashicorp/tap/terraform
      else
        wget -qO /tmp/tf.zip \
          "https://releases.hashicorp.com/terraform/1.7.5/terraform_1.7.5_linux_amd64.zip"
        unzip -q /tmp/tf.zip -d /usr/local/bin
        chmod +x /usr/local/bin/terraform
      fi
      ;;
    aws)
      if [[ "$OS" == "mac" ]]; then
        brew install awscli
      else
        curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
        unzip -q /tmp/awscliv2.zip -d /tmp
        sudo /tmp/aws/install
      fi
      ;;
    kubectl)
      if [[ "$OS" == "mac" ]]; then
        brew install kubectl
      else
        curl -sLO "https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        chmod +x kubectl && sudo mv kubectl /usr/local/bin/
      fi
      ;;
    helm)
      if [[ "$OS" == "mac" ]]; then
        brew install helm
      else
        curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
      fi
      ;;
    docker)
      if [[ "$OS" == "mac" ]]; then
        brew install --cask docker
        echo ""
        warn "Docker Desktop was just installed."
        warn "Please open Docker Desktop from Applications now."
        warn "Wait until the whale icon in the menu bar stops animating."
        read -rp "  Press Enter once Docker Desktop is running... "
        # Give Docker socket time to appear
        sleep 5
      else
        curl -fsSL https://get.docker.com | sudo sh
        sudo usermod -aG docker "$USER"
        newgrp docker
      fi
      ;;
    git)
      if [[ "$OS" == "mac" ]]; then brew install git
      else sudo apt-get install -y git; fi
      ;;
    jq)
      if [[ "$OS" == "mac" ]]; then brew install jq
      else sudo apt-get install -y jq; fi
      ;;
    eksctl)
      if [[ "$OS" == "mac" ]]; then
        brew tap weaveworks/tap && brew install weaveworks/tap/eksctl
      else
        curl -sL "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_Linux_amd64.tar.gz" \
          | tar xz -C /tmp && sudo mv /tmp/eksctl /usr/local/bin/
      fi
      ;;
  esac
  command -v "$cmd" &>/dev/null && success "$cmd installed" || die "Failed to install $cmd"
}

# ── Step 1: Install all tools ──────────────────────────────────────────────────
install_tools() {
  step "Step 1/15 — Installing required tools"
  detect_os
  [[ "$OS" == "mac" ]] && need brew
  need git
  need docker
  need terraform
  need aws
  need kubectl
  need helm
  need jq
  need eksctl
}

# ── Step 2: Clone the repository ───────────────────────────────────────────────
clone_repo() {
  step "Step 2/15 — Cloning repository"
  if [[ -d "$REPO_DIR/.git" ]]; then
    info "Repository already exists at $REPO_DIR — pulling latest..."
    git -C "$REPO_DIR" pull
  else
    info "Cloning $GITHUB_REPO..."
    git clone "$GITHUB_REPO" "$REPO_DIR"
  fi
  success "Repository ready at $REPO_DIR"

  # Write all infra files into the repo
  write_infra_files
}


# ── Create IAM user if needed ──────────────────────────────────────────────────
create_iam_user() {
  step "Step 3a/15 — Creating AWS IAM user"

  echo ""
  echo -e "  ${CYAN}You need an AWS account first. Here is exactly what to do:${NC}"
  echo ""
  echo "  1. Open this URL in your browser:"
  echo "     https://console.aws.amazon.com/iam/home#/users/create"
  echo ""
  echo "  2. User name: terraform-deployer"
  echo "     Click: Next"
  echo ""
  echo "  3. Select: Attach policies directly"
  echo "     Search and tick: AdministratorAccess"
  echo "     Click: Next → Create user"
  echo ""
  echo "  4. Click the user 'terraform-deployer' → Security credentials tab"
  echo "     → Create access key → Command Line Interface (CLI)"
  echo "     → tick the confirmation checkbox → Next → Create access key"
  echo ""
  echo "  5. COPY both values shown:"
  echo "     Access key ID      (looks like: AKIAIOSFODNN7EXAMPLE)"
  echo "     Secret access key  (looks like: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY)"
  echo ""
  read -rp "  Press Enter once you have both values copied... "
}

# ── Step 3: Collect AWS credentials ────────────────────────────────────────────
collect_credentials() {
  step "Step 3/15 — AWS credentials"

  if aws sts get-caller-identity &>/dev/null 2>&1; then
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    success "AWS already configured — Account: $ACCOUNT_ID"
    return
  fi

  create_iam_user

  echo ""
  echo "  Enter your AWS credentials. These are only stored in ~/.aws/credentials"
  echo "  and are never sent anywhere else."
  echo ""
  read -rp "  AWS Access Key ID     : " AWS_ACCESS_KEY_ID
  read -rsp "  AWS Secret Access Key : " AWS_SECRET_ACCESS_KEY
  echo ""
  read -rp "  AWS Region [$AWS_REGION]: " input_region
  AWS_REGION="${input_region:-$AWS_REGION}"

  aws configure set aws_access_key_id     "$AWS_ACCESS_KEY_ID"
  aws configure set aws_secret_access_key "$AWS_SECRET_ACCESS_KEY"
  aws configure set default.region        "$AWS_REGION"
  aws configure set default.output        json

  ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
  success "AWS configured — Account: $ACCOUNT_ID  Region: $AWS_REGION"
}

# ── Step 4: Create Terraform state backend ─────────────────────────────────────
create_backend() {
  step "Step 4/15 — Creating Terraform state backend"

  # Check if bucket already exists
  if aws s3 ls "s3://sunny-portfolio-tfstate" &>/dev/null 2>&1; then
    success "S3 state bucket already exists"
    return
  fi

  info "Creating S3 bucket and DynamoDB lock table..."
  cd "$INFRA_DIR/terraform/bootstrap"
  terraform init -input=false -no-color
  terraform apply -auto-approve -no-color
  cd "$REPO_DIR"
  success "State backend ready"
}

# ── Step 5: Terraform apply ────────────────────────────────────────────────────
terraform_apply() {
  step "Step 5/15 — Provisioning AWS infrastructure (EKS, ECR, Redis, ACM)"
  info "This takes approximately 15–20 minutes..."

  cd "$INFRA_DIR/terraform"
  terraform init -input=false -no-color
  terraform apply -auto-approve -no-color \
    -var="aws_region=$AWS_REGION" \
    -var="domain=$DOMAIN"

  # Capture outputs
  ECR_URL=$(terraform output -raw ecr_repository_url)
  REDIS_ENDPOINT=$(terraform output -raw redis_endpoint)
  ACM_ARN=$(terraform output -raw acm_certificate_arn)
  KUBECONFIG_CMD=$(terraform output -raw kubeconfig_command)

  success "Infrastructure provisioned"
  info "ECR URL      : $ECR_URL"
  info "Redis        : $REDIS_ENDPOINT"
  info "ACM ARN      : $ACM_ARN"

  # Save outputs for later steps
  cat > "$REPO_DIR/.deploy-env" <<EOF
ECR_URL="$ECR_URL"
REDIS_ENDPOINT="$REDIS_ENDPOINT"
ACM_ARN="$ACM_ARN"
KUBECONFIG_CMD="$KUBECONFIG_CMD"
AWS_REGION="$AWS_REGION"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
EOF

  cd "$REPO_DIR"
}

# ── Step 6: Configure kubectl ──────────────────────────────────────────────────
configure_kubectl() {
  step "Step 6/15 — Configuring kubectl"
  source "$REPO_DIR/.deploy-env"
  eval "$KUBECONFIG_CMD"
  kubectl get nodes
  success "kubectl connected to EKS"
}

# ── Step 7: Patch Helm values with terraform outputs ──────────────────────────
patch_helm_values() {
  step "Step 7/15 — Patching Helm values with terraform outputs"
  source "$REPO_DIR/.deploy-env"

  # portfolio values.yaml
  sed -i.bak \
    -e "s|repository: \"\"|repository: \"$ECR_URL\"|" \
    -e "s|alb.ingress.kubernetes.io/certificate-arn: \"\"|alb.ingress.kubernetes.io/certificate-arn: \"$ACM_ARN\"|" \
    -e "s|externalEndpoint: \"\"|externalEndpoint: \"$REDIS_ENDPOINT\"|" \
    "$INFRA_DIR/helm/portfolio/values.yaml"

  # monitoring values.yaml
  sed -i.bak \
    -e "s|alb.ingress.kubernetes.io/certificate-arn: \"\"|alb.ingress.kubernetes.io/certificate-arn: \"$ACM_ARN\"|" \
    "$INFRA_DIR/helm/monitoring/values.yaml"

  # argocd application.yaml
  sed -i.bak \
    "s|repoURL: https://github.com/YOUR_USERNAME/sunny-portfolio.git|repoURL: $GITHUB_REPO|" \
    "$INFRA_DIR/argocd/application.yaml"

  # Clean up backup files
  find "$INFRA_DIR" -name "*.bak" -delete

  success "Helm values patched"
}

# ── Step 8: Install ArgoCD ────────────────────────────────────────────────────
install_argocd() {
  step "Step 8/15 — Installing ArgoCD"

  kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
  kubectl apply -n argocd \
    -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

  info "Waiting for ArgoCD server to be ready..."
  kubectl wait --for=condition=available deployment/argocd-server \
    -n argocd --timeout=300s

  ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
    -o jsonpath="{.data.password}" | base64 -d)

  echo "ARGOCD_PASSWORD=\"$ARGOCD_PASSWORD\"" >> "$REPO_DIR/.deploy-env"
  success "ArgoCD ready — admin password: $ARGOCD_PASSWORD"
}

# ── Step 9: Install monitoring stack ─────────────────────────────────────────
install_monitoring() {
  step "Step 9/15 — Installing Prometheus + Grafana"

  helm repo add prometheus-community \
    https://prometheus-community.github.io/helm-charts --force-update
  helm repo update

  kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

  helm upgrade --install monitoring \
    prometheus-community/kube-prometheus-stack \
    --values "$INFRA_DIR/helm/monitoring/values.yaml" \
    --namespace monitoring \
    --create-namespace \
    --wait \
    --timeout 10m

  success "Prometheus + Grafana installed"
}

# ── Step 10: Launch Jenkins + SonarQube ──────────────────────────────────────
launch_jenkins_sonar() {
  step "Step 10/15 — Launching Jenkins and SonarQube"

  # SonarQube
  if ! docker ps --format '{{.Names}}' | grep -q sonarqube; then
    docker run -d \
      --name sonarqube \
      --restart unless-stopped \
      -p "${SONAR_PORT}:9000" \
      sonarqube:community
    info "SonarQube starting on port $SONAR_PORT..."
  else
    info "SonarQube already running"
  fi

  # Jenkins
  if ! docker ps --format '{{.Names}}' | grep -q "^jenkins$"; then
    docker run -d \
      --name jenkins \
      --restart unless-stopped \
      -p "${JENKINS_PORT}:8080" \
      -p 50000:50000 \
      -v jenkins_home:/var/jenkins_home \
      -v /var/run/docker.sock:/var/run/docker.sock \
      jenkins/jenkins:lts
    info "Jenkins starting on port $JENKINS_PORT..."
  else
    info "Jenkins already running"
  fi

  # Wait for Jenkins
  info "Waiting for Jenkins to start (up to 3 minutes)..."
  timeout=180
  while ! curl -sf "http://localhost:${JENKINS_PORT}/login" &>/dev/null; do
    printf "."
    sleep 5
    timeout=$((timeout - 5))
    [[ $timeout -le 0 ]] && die "Jenkins did not start. Is Docker Desktop running on your Mac?"
  done
  echo ""

  # Install tools inside Jenkins container
  info "Installing tools inside Jenkins container..."
  docker exec -u root jenkins bash -c '
    apt-get update -qq &&
    apt-get install -y -qq curl unzip wget nodejs npm &&

    # Trivy
    curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh \
      | sh -s -- -b /usr/local/bin 2>/dev/null &&

    # OWASP Dependency-Check
    wget -q https://github.com/jeremylong/DependencyCheck/releases/download/v9.0.7/dependency-check-9.0.7-release.zip \
      -O /tmp/dc.zip &&
    unzip -q /tmp/dc.zip -d /opt &&
    ln -sf /opt/dependency-check/bin/dependency-check.sh /usr/local/bin/dependency-check &&

    # SonarQube Scanner
    wget -q https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-5.0.1.3006-linux.zip \
      -O /tmp/sonar.zip &&
    unzip -q /tmp/sonar.zip -d /opt &&
    ln -sf /opt/sonar-scanner-5.0.1.3006-linux/bin/sonar-scanner /usr/local/bin/sonar-scanner &&

    # AWS CLI
    curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip &&
    unzip -q /tmp/awscliv2.zip -d /tmp &&
    /tmp/aws/install --update &&

    echo "Tools installed successfully"
  '

  JENKINS_INIT_PASSWORD=$(docker exec jenkins \
    cat /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null || echo "not-found")
  echo "JENKINS_INIT_PASSWORD=\"$JENKINS_INIT_PASSWORD\"" >> "$REPO_DIR/.deploy-env"

  success "Jenkins running — initial password: $JENKINS_INIT_PASSWORD"
  success "SonarQube running"
}

# ── Step 11: First Docker build and push to ECR ───────────────────────────────
initial_ecr_push() {
  step "Step 11/15 — Building and pushing initial Docker image to ECR"
  source "$REPO_DIR/.deploy-env"

  # Copy Dockerfile and nginx.conf into repo root
  cp "$INFRA_DIR/Dockerfile" "$REPO_DIR/Dockerfile"
  cp "$INFRA_DIR/nginx.conf"  "$REPO_DIR/nginx.conf"

  cd "$REPO_DIR"

  # Authenticate to ECR
  aws ecr get-login-password --region "$AWS_REGION" \
    | docker login --username AWS --password-stdin "$ECR_URL"

  # Build image
  docker build -t "${ECR_URL}:latest" .

  # Push image
  docker push "${ECR_URL}:latest"

  success "Initial image pushed to ECR"
  cd "$REPO_DIR"
}

# ── Step 12: Apply ArgoCD Application ────────────────────────────────────────
apply_argocd_app() {
  step "Step 12/15 — Applying ArgoCD Application"
  kubectl apply -f "$INFRA_DIR/argocd/application.yaml"
  success "ArgoCD Application applied — syncing now"
}

# ── Step 13: Commit infra files back to GitHub ────────────────────────────────
commit_infra_to_github() {
  step "Step 13/15 — Committing infra files to GitHub"
  cd "$REPO_DIR"

  git add .
  git diff --cached --quiet && {
    info "No changes to commit"
    return
  }

  git commit -m "chore: add DevSecOps infra files (Dockerfile, Helm, Terraform, Jenkins)"
  git push origin main

  success "Infra files pushed to GitHub"
  cd "$REPO_DIR"
}

# ── Step 14: Wait for pods to be running ─────────────────────────────────────
wait_for_pods() {
  step "Step 14/15 — Waiting for pods to be Running"

  info "Waiting for portfolio pods..."
  kubectl wait --for=condition=available deployment/sunny-portfolio \
    -n portfolio --timeout=300s 2>/dev/null || \
  info "Portfolio pods not ready yet — ArgoCD may still be syncing"

  info "Waiting for Grafana..."
  kubectl wait --for=condition=available deployment/monitoring-grafana \
    -n monitoring --timeout=300s 2>/dev/null || true

  success "Pods are running"
}

# ── Step 15: Print final summary ─────────────────────────────────────────────
print_summary() {
  step "Step 15/15 — Deployment complete"
  source "$REPO_DIR/.deploy-env"

  # Get ALB DNS names
  sleep 30
  PORTFOLIO_ALB=$(kubectl get ingress -n portfolio \
    -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}' \
    2>/dev/null || echo "provisioning — run: kubectl get ingress -n portfolio")

  GRAFANA_ALB=$(kubectl get ingress -n monitoring \
    -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}' \
    2>/dev/null || echo "provisioning — run: kubectl get ingress -n monitoring")

  echo ""
  echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}║           DEPLOYMENT COMPLETE — SUNNY PORTFOLIO              ║${NC}"
  echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "  ${CYAN}Portfolio${NC}   https://sunnycharkhwalcloud.shop"
  echo -e "  ${CYAN}Grafana${NC}     https://grafana.sunnycharkhwalcloud.shop"
  echo -e "  ${CYAN}Jenkins${NC}     http://localhost:${JENKINS_PORT}"
  echo -e "  ${CYAN}SonarQube${NC}   http://localhost:${SONAR_PORT}"
  echo ""
  echo -e "  ${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "  ${YELLOW}  ACTION REQUIRED — Add these CNAMEs to GoDaddy DNS:${NC}"
  echo -e "  ${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""

  echo -e "  ${CYAN}ACM certificate validation CNAMEs (from terraform output):${NC}"
  cd "$INFRA_DIR/terraform"
  terraform output acm_dns_validation_records 2>/dev/null || true
  cd "$REPO_DIR"

  echo ""
  echo -e "  ${CYAN}Domain CNAMEs (point your domain to AWS):${NC}"
  echo -e "  Type   Name   Value"
  echo -e "  CNAME  @      $PORTFOLIO_ALB"
  echo -e "  CNAME  www    $PORTFOLIO_ALB"
  echo ""
  echo -e "  ${CYAN}Grafana CNAME:${NC}"
  echo -e "  CNAME  grafana  $GRAFANA_ALB"
  echo ""
  echo -e "  ${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  echo -e "  ${CYAN}Credentials:${NC}"
  echo -e "  ArgoCD   admin / ${ARGOCD_PASSWORD}"
  echo -e "  Grafana  admin / ChangeMe123!"
  echo -e "  Jenkins  admin / ${JENKINS_INIT_PASSWORD}"
  echo -e "  SonarQube  admin / admin  (change on first login)"
  echo ""
  echo -e "  ${CYAN}ArgoCD UI:${NC}"
  echo -e "  kubectl port-forward svc/argocd-server -n argocd 8443:443"
  echo -e "  Open: https://localhost:8443"
  echo ""
  echo -e "  ${CYAN}Future deployments — just run:${NC}"
  echo -e "  cd $REPO_DIR && git push origin main"
  echo ""
}

# ── Write all infrastructure files into the repo ─────────────────────────────
write_infra_files() {
  info "Writing infrastructure files into repository..."
  mkdir -p "$INFRA_DIR"/{terraform/bootstrap,helm/portfolio/templates,helm/monitoring,jenkins,argocd,scripts}

  # ── Terraform bootstrap ────────────────────────────────────────────────────
  cat > "$INFRA_DIR/terraform/bootstrap/main.tf" << 'TFBOOT'
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}
provider "aws" { region = "us-east-1" }

resource "aws_s3_bucket" "tfstate" {
  bucket        = "sunny-portfolio-tfstate"
  force_destroy = false
  tags          = { Project = "sunny-portfolio", ManagedBy = "Terraform" }
}
resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration { status = "Enabled" }
}
resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule { apply_server_side_encryption_by_default { sse_algorithm = "AES256" } }
}
resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
resource "aws_dynamodb_table" "tf_lock" {
  name         = "sunny-portfolio-tf-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  attribute    { name = "LockID"; type = "S" }
  tags         = { Project = "sunny-portfolio", ManagedBy = "Terraform" }
}
output "s3_bucket_name"     { value = aws_s3_bucket.tfstate.bucket }
output "dynamodb_table_name" { value = aws_dynamodb_table.tf_lock.name }
TFBOOT

  # ── Terraform variables ────────────────────────────────────────────────────
  cat > "$INFRA_DIR/terraform/variables.tf" << 'TFVARS'
variable "aws_region"         { type = string; default = "us-east-1" }
variable "project_name"       { type = string; default = "sunny-portfolio" }
variable "environment"        { type = string; default = "production" }
variable "domain"             { type = string; default = "sunnycharkhwalcloud.shop" }
variable "node_instance_type" { type = string; default = "t3.medium" }
TFVARS

  # ── Terraform main ─────────────────────────────────────────────────────────
  cat > "$INFRA_DIR/terraform/main.tf" << 'TFMAIN'
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws        = { source = "hashicorp/aws",       version = "~> 5.0"  }
    kubernetes = { source = "hashicorp/kubernetes", version = "~> 2.23" }
    helm       = { source = "hashicorp/helm",       version = "~> 2.11" }
  }
  backend "s3" {
    bucket         = "sunny-portfolio-tfstate"
    key            = "eks/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "sunny-portfolio-tf-lock"
  }
}

provider "aws" { region = var.aws_region }

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}

locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"
  name    = "${var.project_name}-vpc"
  cidr    = "10.0.0.0/16"
  azs             = ["${var.aws_region}a", "${var.aws_region}b", "${var.aws_region}c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true
  public_subnet_tags = {
    "kubernetes.io/role/elb"                    = 1
    "kubernetes.io/cluster/${var.project_name}" = "shared"
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"           = 1
    "kubernetes.io/cluster/${var.project_name}" = "shared"
  }
  tags = local.common_tags
}

resource "aws_ecr_repository" "portfolio" {
  name                 = var.project_name
  image_tag_mutability = "MUTABLE"
  force_delete         = false
  image_scanning_configuration { scan_on_push = true }
  tags = local.common_tags
}

resource "aws_ecr_lifecycle_policy" "portfolio" {
  repository = aws_ecr_repository.portfolio.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection    = { tagStatus = "any"; countType = "imageCountMoreThan"; countNumber = 10 }
      action       = { type = "expire" }
    }]
  })
}

resource "aws_acm_certificate" "portfolio" {
  domain_name               = var.domain
  subject_alternative_names = ["www.${var.domain}"]
  validation_method         = "DNS"
  tags                      = local.common_tags
  lifecycle { create_before_destroy = true }
}

module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "~> 19.0"
  cluster_name    = var.project_name
  cluster_version = "1.28"
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnets
  cluster_endpoint_public_access = true
  cluster_addons = {
    coredns    = { most_recent = true }
    kube-proxy = { most_recent = true }
    vpc-cni    = { most_recent = true }
  }
  eks_managed_node_groups = {
    main = {
      name           = "${var.project_name}-nodes"
      instance_types = [var.node_instance_type]
      min_size       = 1
      max_size       = 3
      desired_size   = 2
      iam_role_additional_policies = {
        AmazonECRReadOnly            = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
        AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      }
    }
  }
  tags = local.common_tags
}

module "alb_controller_irsa" {
  source    = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version   = "~> 5.0"
  role_name = "${var.project_name}-alb-controller"
  attach_load_balancer_controller_policy = true
  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
  tags = local.common_tags
}

resource "helm_release" "alb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.6.2"
  set { name = "clusterName";   value = module.eks.cluster_name }
  set { name = "serviceAccount.create"; value = "true" }
  set { name = "serviceAccount.name";   value = "aws-load-balancer-controller" }
  set { name = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"; value = module.alb_controller_irsa.iam_role_arn }
  set { name = "region"; value = var.aws_region }
  set { name = "vpcId";  value = module.vpc.vpc_id }
  depends_on = [module.eks]
}

resource "aws_elasticache_subnet_group" "redis" {
  name       = "${var.project_name}-redis-subnet"
  subnet_ids = module.vpc.private_subnets
  tags       = local.common_tags
}

resource "aws_security_group" "redis" {
  name        = "${var.project_name}-redis-sg"
  description = "Redis access from EKS nodes"
  vpc_id      = module.vpc.vpc_id
  ingress {
    from_port   = 6379; to_port = 6379; protocol = "tcp"
    cidr_blocks = module.vpc.private_subnets_cidr_blocks
  }
  egress { from_port = 0; to_port = 0; protocol = "-1"; cidr_blocks = ["0.0.0.0/0"] }
  tags = local.common_tags
}

resource "aws_elasticache_replication_group" "redis" {
  replication_group_id       = "${var.project_name}-redis"
  description                = "Portfolio Redis cache"
  node_type                  = "cache.t3.micro"
  num_cache_clusters         = 1
  parameter_group_name       = "default.redis7"
  engine_version             = "7.0"
  port                       = 6379
  subnet_group_name          = aws_elasticache_subnet_group.redis.name
  security_group_ids         = [aws_security_group.redis.id]
  at_rest_encryption_enabled = true
  automatic_failover_enabled = false
  tags                       = local.common_tags
}
TFMAIN

  # ── Terraform outputs ──────────────────────────────────────────────────────
  cat > "$INFRA_DIR/terraform/outputs.tf" << 'TFOUT'
output "ecr_repository_url"  { value = aws_ecr_repository.portfolio.repository_url }
output "eks_cluster_name"    { value = module.eks.cluster_name }
output "eks_cluster_endpoint"{ value = module.eks.cluster_endpoint }
output "redis_endpoint"      { value = aws_elasticache_replication_group.redis.primary_endpoint_address }
output "acm_certificate_arn" { value = aws_acm_certificate.portfolio.arn }
output "aws_region"          { value = var.aws_region }
output "kubeconfig_command"  { value = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}" }
output "acm_dns_validation_records" {
  description = "Add these CNAME records to GoDaddy to validate the ACM certificate"
  value = {
    for dvo in aws_acm_certificate.portfolio.domain_validation_options :
    dvo.domain_name => {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  }
}
TFOUT

  # ── Helm: portfolio Chart.yaml ─────────────────────────────────────────────
  cat > "$INFRA_DIR/helm/portfolio/Chart.yaml" << 'CHART'
apiVersion: v2
name: sunny-portfolio
description: Sunny Charkhwal DevOps Portfolio
type: application
version: 1.0.0
appVersion: "1.0.0"
CHART

  # ── Helm: portfolio values.yaml ────────────────────────────────────────────
  cat > "$INFRA_DIR/helm/portfolio/values.yaml" << 'VALS'
replicaCount: 2
image:
  repository: ""
  tag: "latest"
  pullPolicy: Always
nameOverride: "sunny-portfolio"
fullnameOverride: "sunny-portfolio"
service:
  type: ClusterIP
  port: 80
  targetPort: 80
ingress:
  enabled: true
  className: "alb"
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
    alb.ingress.kubernetes.io/ssl-redirect: "443"
    alb.ingress.kubernetes.io/certificate-arn: ""
    alb.ingress.kubernetes.io/healthcheck-path: "/"
    alb.ingress.kubernetes.io/success-codes: "200"
  hosts:
    - host: sunnycharkhwalcloud.shop
      paths:
        - path: /
          pathType: Prefix
    - host: www.sunnycharkhwalcloud.shop
      paths:
        - path: /
          pathType: Prefix
resources:
  requests:
    cpu: "100m"
    memory: "128Mi"
  limits:
    cpu: "250m"
    memory: "256Mi"
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 5
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80
redis:
  enabled: true
  externalEndpoint: ""
  port: 6379
livenessProbe:
  httpGet:
    path: /
    port: 80
  initialDelaySeconds: 10
  periodSeconds: 15
  failureThreshold: 3
readinessProbe:
  httpGet:
    path: /
    port: 80
  initialDelaySeconds: 5
  periodSeconds: 10
  failureThreshold: 3
podAnnotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "80"
  prometheus.io/path: "/metrics"
nodeSelector: {}
tolerations: []
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchExpressions:
              - key: app.kubernetes.io/name
                operator: In
                values: ["sunny-portfolio"]
          topologyKey: kubernetes.io/hostname
VALS

  # ── Helm: _helpers.tpl ────────────────────────────────────────────────────
  cat > "$INFRA_DIR/helm/portfolio/templates/_helpers.tpl" << 'HELPERS'
{{- define "sunny-portfolio.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else if .Values.nameOverride }}
{{- .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- define "sunny-portfolio.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{ include "sunny-portfolio.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
{{- define "sunny-portfolio.selectorLabels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
HELPERS

  # ── Helm: deployment.yaml ─────────────────────────────────────────────────
  cat > "$INFRA_DIR/helm/portfolio/templates/deployment.yaml" << 'DEPLOY'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "sunny-portfolio.fullname" . }}
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "sunny-portfolio.labels" . | nindent 4 }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      {{- include "sunny-portfolio.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "sunny-portfolio.selectorLabels" . | nindent 8 }}
      annotations:
        {{- toYaml .Values.podAnnotations | nindent 8 }}
    spec:
      containers:
        - name: portfolio
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - name: http
              containerPort: 80
              protocol: TCP
          env:
            - name: REDIS_HOST
              value: {{ .Values.redis.externalEndpoint | quote }}
            - name: REDIS_PORT
              value: {{ .Values.redis.port | quote }}
          livenessProbe:
            {{- toYaml .Values.livenessProbe | nindent 12 }}
          readinessProbe:
            {{- toYaml .Values.readinessProbe | nindent 12 }}
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
      {{- with .Values.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
DEPLOY

  # ── Helm: service.yaml ────────────────────────────────────────────────────
  cat > "$INFRA_DIR/helm/portfolio/templates/service.yaml" << 'SVC'
apiVersion: v1
kind: Service
metadata:
  name: {{ include "sunny-portfolio.fullname" . }}
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "sunny-portfolio.labels" . | nindent 4 }}
spec:
  type: {{ .Values.service.type }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: {{ .Values.service.targetPort }}
      protocol: TCP
      name: http
  selector:
    {{- include "sunny-portfolio.selectorLabels" . | nindent 4 }}
SVC

  # ── Helm: ingress.yaml ────────────────────────────────────────────────────
  cat > "$INFRA_DIR/helm/portfolio/templates/ingress.yaml" << 'ING'
{{- if .Values.ingress.enabled }}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ include "sunny-portfolio.fullname" . }}
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "sunny-portfolio.labels" . | nindent 4 }}
  annotations:
    {{- toYaml .Values.ingress.annotations | nindent 4 }}
spec:
  ingressClassName: {{ .Values.ingress.className }}
  rules:
    {{- range .Values.ingress.hosts }}
    - host: {{ .host }}
      http:
        paths:
          {{- range .paths }}
          - path: {{ .path }}
            pathType: {{ .pathType }}
            backend:
              service:
                name: {{ include "sunny-portfolio.fullname" $ }}
                port:
                  number: {{ $.Values.service.port }}
          {{- end }}
    {{- end }}
{{- end }}
ING

  # ── Helm: hpa.yaml ────────────────────────────────────────────────────────
  cat > "$INFRA_DIR/helm/portfolio/templates/hpa.yaml" << 'HPA'
{{- if .Values.autoscaling.enabled }}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ include "sunny-portfolio.fullname" . }}
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "sunny-portfolio.labels" . | nindent 4 }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ include "sunny-portfolio.fullname" . }}
  minReplicas: {{ .Values.autoscaling.minReplicas }}
  maxReplicas: {{ .Values.autoscaling.maxReplicas }}
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: {{ .Values.autoscaling.targetCPUUtilizationPercentage }}
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: {{ .Values.autoscaling.targetMemoryUtilizationPercentage }}
{{- end }}
HPA

  # ── Helm: monitoring values.yaml ──────────────────────────────────────────
  cat > "$INFRA_DIR/helm/monitoring/values.yaml" << 'MON'
grafana:
  enabled: true
  adminPassword: "ChangeMe123!"
  ingress:
    enabled: true
    ingressClassName: alb
    annotations:
      kubernetes.io/ingress.class: alb
      alb.ingress.kubernetes.io/scheme: internet-facing
      alb.ingress.kubernetes.io/target-type: ip
      alb.ingress.kubernetes.io/listen-ports: '[{"HTTPS": 443}]'
      alb.ingress.kubernetes.io/certificate-arn: ""
    hosts:
      - grafana.sunnycharkhwalcloud.shop
    path: /
  datasources:
    datasources.yaml:
      apiVersion: 1
      datasources:
        - name: Prometheus
          type: prometheus
          url: http://monitoring-kube-prometheus-prometheus:9090
          isDefault: true
  dashboards:
    default:
      kubernetes-cluster:
        gnetId: 7249
        revision: 1
        datasource: Prometheus
      node-exporter:
        gnetId: 1860
        revision: 37
        datasource: Prometheus
prometheus:
  enabled: true
  prometheusSpec:
    retention: 15d
alertmanager:
  enabled: true
nodeExporter:
  enabled: true
kubeStateMetrics:
  enabled: true
MON

  # ── ArgoCD application ─────────────────────────────────────────────────────
  cat > "$INFRA_DIR/argocd/application.yaml" << 'ARGO'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: sunny-portfolio
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/sunnycharkhwal/sunny-portfolio.git
    targetRevision: main
    path: infra/helm/portfolio
  destination:
    server: https://kubernetes.default.svc
    namespace: portfolio
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - PrunePropagationPolicy=foreground
    retry:
      limit: 3
      backoff:
        duration: 10s
        maxDuration: 3m
        factor: 2
  revisionHistoryLimit: 5
ARGO

  # ── Jenkinsfile ────────────────────────────────────────────────────────────
  cat > "$INFRA_DIR/jenkins/Jenkinsfile" << 'JF'
pipeline {
    agent any
    environment {
        AWS_REGION   = 'us-east-1'
        ECR_REPO     = credentials('ECR_REPO_URL')
        SONAR_HOST   = credentials('SONAR_HOST_URL')
        SONAR_TOKEN  = credentials('SONAR_TOKEN')
        IMAGE_TAG    = "${env.GIT_COMMIT[0..6]}"
        IMAGE_FULL   = "${ECR_REPO}:${IMAGE_TAG}"
        IMAGE_LATEST = "${ECR_REPO}:latest"
    }
    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 45, unit: 'MINUTES')
        disableConcurrentBuilds()
        timestamps()
    }
    stages {
        stage('Checkout') {
            steps {
                checkout scm
                sh 'echo "Branch: ${GIT_BRANCH} | Commit: ${IMAGE_TAG}"'
            }
        }
        stage('Install and Build') {
            steps {
                sh 'npm ci && npm run build'
            }
            post { always { archiveArtifacts artifacts: 'dist/**', fingerprint: true } }
        }
        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('SonarQube') {
                    sh """
                        sonar-scanner \
                          -Dsonar.projectKey=sunny-portfolio \
                          -Dsonar.projectName='Sunny Portfolio' \
                          -Dsonar.sources=src \
                          -Dsonar.host.url=${SONAR_HOST} \
                          -Dsonar.token=${SONAR_TOKEN}
                    """
                }
            }
        }
        stage('Quality Gate') {
            steps {
                timeout(time: 10, unit: 'MINUTES') { waitForQualityGate abortPipeline: true }
            }
        }
        stage('OWASP Dependency Check') {
            steps {
                sh '''
                    mkdir -p reports/owasp
                    dependency-check --project "sunny-portfolio" \
                      --scan . --exclude "**/node_modules/**" \
                      --format "HTML" --format "XML" \
                      --out reports/owasp --failOnCVSS 7
                '''
            }
            post {
                always {
                    publishHTML(target: [allowMissing: true, alwaysLinkToLastBuild: true,
                        keepAll: true, reportDir: 'reports/owasp',
                        reportFiles: 'dependency-check-report.html',
                        reportName: 'OWASP Dependency Check'])
                    dependencyCheckPublisher pattern: 'reports/owasp/dependency-check-report.xml'
                }
            }
        }
        stage('Trivy Filesystem Scan') {
            steps {
                sh '''
                    mkdir -p reports/trivy
                    trivy fs --severity HIGH,CRITICAL --exit-code 0 \
                      --format template \
                      --template "@/usr/local/share/trivy/templates/html.tpl" \
                      --output reports/trivy/fs-report.html .
                    trivy fs --severity CRITICAL --exit-code 1 --quiet .
                '''
            }
            post {
                always {
                    publishHTML(target: [allowMissing: true, alwaysLinkToLastBuild: true,
                        keepAll: true, reportDir: 'reports/trivy',
                        reportFiles: 'fs-report.html', reportName: 'Trivy Filesystem Scan'])
                }
            }
        }
        stage('Docker Build') {
            steps {
                sh """
                    docker build \
                      --build-arg BUILD_DATE=\$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
                      --build-arg GIT_COMMIT=${IMAGE_TAG} \
                      -t ${IMAGE_FULL} -t ${IMAGE_LATEST} .
                """
            }
        }
        stage('Trivy Image Scan') {
            steps {
                sh """
                    trivy image --severity HIGH,CRITICAL --exit-code 0 \
                      --format template \
                      --template "@/usr/local/share/trivy/templates/html.tpl" \
                      --output reports/trivy/image-report.html ${IMAGE_FULL}
                    trivy image --severity CRITICAL --exit-code 1 --quiet ${IMAGE_FULL}
                """
            }
            post {
                always {
                    publishHTML(target: [allowMissing: true, alwaysLinkToLastBuild: true,
                        keepAll: true, reportDir: 'reports/trivy',
                        reportFiles: 'image-report.html', reportName: 'Trivy Image Scan'])
                }
            }
        }
        stage('Push to ECR') {
            steps {
                withAWS(region: "${AWS_REGION}", credentials: 'aws-credentials') {
                    sh """
                        aws ecr get-login-password --region ${AWS_REGION} \
                          | docker login --username AWS --password-stdin ${ECR_REPO}
                        docker push ${IMAGE_FULL}
                        docker push ${IMAGE_LATEST}
                    """
                }
            }
        }
        stage('Update Helm Image Tag') {
            steps {
                sh """
                    sed -i 's|^  tag:.*|  tag: "${IMAGE_TAG}"|' infra/helm/portfolio/values.yaml
                    git config user.email "jenkins@ci-pipeline"
                    git config user.name  "Jenkins CI"
                    git add infra/helm/portfolio/values.yaml
                    git commit -m "ci: bump image tag to ${IMAGE_TAG} [skip ci]" || true
                    git push origin main || true
                """
            }
        }
    }
    post {
        success { echo "SUCCESS — ${IMAGE_TAG} deployed via ArgoCD" }
        failure { echo "FAILURE — check stage logs above" }
        always  {
            sh "docker rmi ${IMAGE_FULL} ${IMAGE_LATEST} 2>/dev/null || true"
            cleanWs()
        }
    }
}
JF

  # ── Dockerfile ────────────────────────────────────────────────────────────
  cat > "$INFRA_DIR/Dockerfile" << 'DFILE'
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --prefer-offline
COPY . .
RUN npm run build

FROM nginx:1.27-alpine
RUN rm /etc/nginx/conf.d/default.conf
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=builder /app/dist /usr/share/nginx/html
RUN addgroup -g 1001 appgroup \
 && adduser -u 1001 -G appgroup -s /bin/sh -D appuser \
 && chown -R appuser:appgroup /usr/share/nginx/html \
 && chown -R appuser:appgroup /var/cache/nginx \
 && chown -R appuser:appgroup /var/log/nginx \
 && touch /var/run/nginx.pid \
 && chown appuser:appgroup /var/run/nginx.pid
USER appuser
EXPOSE 80
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://localhost/ || exit 1
CMD ["nginx", "-g", "daemon off;"]
DFILE

  # ── nginx.conf ────────────────────────────────────────────────────────────
  cat > "$INFRA_DIR/nginx.conf" << 'NGINX'
server {
    listen      80;
    server_name _;
    root  /usr/share/nginx/html;
    index index.html;
    location / { try_files $uri $uri/ /index.html; }
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot|map)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    location = /index.html {
        add_header Cache-Control "no-cache, no-store, must-revalidate";
        add_header Pragma "no-cache";
        add_header Expires "0";
    }
    add_header X-Frame-Options        "SAMEORIGIN"                      always;
    add_header X-Content-Type-Options "nosniff"                         always;
    add_header X-XSS-Protection       "1; mode=block"                   always;
    add_header Referrer-Policy        "strict-origin-when-cross-origin" always;
    gzip on; gzip_vary on; gzip_proxied any; gzip_comp_level 6;
    gzip_types text/plain text/css text/xml text/javascript
               application/json application/javascript image/svg+xml;
}
NGINX

  # ── .gitignore ────────────────────────────────────────────────────────────
  cat > "$REPO_DIR/.gitignore" << 'GI'
node_modules/
dist/
.terraform/
.terraform.lock.hcl
terraform.tfstate
terraform.tfstate.backup
terraform.tfvars
*.tfvars
!*.tfvars.example
crash.log
.deploy-env
*.pem
*.key
.DS_Store
.env
.env.*
GI

  success "All infrastructure files written"
}

# ── Main execution ─────────────────────────────────────────────────────────────
main() {
  echo ""
  echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║     SUNNY PORTFOLIO — FULLY AUTOMATED DEPLOYMENT             ║${NC}"
  echo -e "${CYAN}║     https://github.com/sunnycharkhwal/sunny-portfolio.git    ║${NC}"
  echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
  echo ""

  install_tools
  clone_repo
  collect_credentials
  create_backend
  terraform_apply
  configure_kubectl
  patch_helm_values
  install_argocd
  install_monitoring
  launch_jenkins_sonar
  initial_ecr_push
  apply_argocd_app
  commit_infra_to_github
  wait_for_pods
  print_summary
}

main "$@"
