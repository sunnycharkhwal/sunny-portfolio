#!/usr/bin/env bash
# =============================================================================
#  setup.sh — Cluster bootstrap + full deployment summary
#  Run once after terraform apply.
#  At the end, prints a complete list of every resource created.
# =============================================================================
set -euo pipefail

CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'
info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
header()  { echo -e "\n${BOLD}${BLUE}$*${NC}"; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INFRA_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TF_DIR="$INFRA_DIR/terraform"

# ── Read all values from terraform output ─────────────────────────────────────
AWS_REGION=$(terraform    -chdir="$TF_DIR" output -raw aws_region)
CLUSTER_NAME=$(terraform  -chdir="$TF_DIR" output -raw eks_cluster_name)
ECR_URL=$(terraform       -chdir="$TF_DIR" output -raw ecr_repository_url)
REDIS_HOST=$(terraform    -chdir="$TF_DIR" output -raw redis_endpoint)
ACM_ARN=$(terraform       -chdir="$TF_DIR" output -raw acm_certificate_arn)
KUBECONFIG_CMD=$(terraform -chdir="$TF_DIR" output -raw kubeconfig_command)
VPC_ID=$(terraform        -chdir="$TF_DIR" output -raw vpc_id)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo ""
echo -e "${BOLD}${CYAN}══════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${CYAN}  Sunny Portfolio — Cluster Bootstrap${NC}"
echo -e "${BOLD}${CYAN}══════════════════════════════════════════════════════${NC}"

# ── Step 1: kubectl ────────────────────────────────────────────────────────────
info "[1/6] Connecting kubectl to EKS..."
eval "$KUBECONFIG_CMD"
kubectl cluster-info --request-timeout=10s
success "kubectl connected"

# ── Step 2: ArgoCD ────────────────────────────────────────────────────────────
info "[2/6] Installing ArgoCD..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml \
  --request-timeout=60s

info "Waiting for ArgoCD server (up to 5 minutes)..."
kubectl wait --for=condition=available deployment/argocd-server \
  -n argocd --timeout=300s

ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d)
success "ArgoCD ready"

# ── Step 3: Prometheus + Grafana ──────────────────────────────────────────────
info "[3/6] Installing Prometheus + Grafana..."
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

# ── Step 4: ArgoCD Application ────────────────────────────────────────────────
info "[4/6] Applying ArgoCD Application..."
kubectl apply -f "$INFRA_DIR/argocd/application.yaml"
success "ArgoCD Application applied — GitOps sync started"

# ── Step 5: Wait for ALB ──────────────────────────────────────────────────────
info "[5/6] Waiting 90s for ALB to provision..."
sleep 90

PORTFOLIO_ALB=$(kubectl get ingress -n portfolio \
  -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}' \
  2>/dev/null || echo "still-provisioning — rerun: kubectl get ingress -n portfolio")

GRAFANA_ALB=$(kubectl get ingress -n monitoring \
  -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}' \
  2>/dev/null || echo "still-provisioning — rerun: kubectl get ingress -n monitoring")

# ── Step 6: Collect full resource inventory ───────────────────────────────────
info "[6/6] Collecting resource inventory..."

# Node info
NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ')
NODE_LIST=$(kubectl get nodes \
  -o custom-columns="NAME:.metadata.name,STATUS:.status.conditions[-1].type,TYPE:.metadata.labels.node\.kubernetes\.io/instance-type" \
  --no-headers 2>/dev/null || echo "  (unavailable)")

# Pod counts per namespace
PODS_PORTFOLIO=$(kubectl get pods -n portfolio  --no-headers 2>/dev/null | wc -l | tr -d ' ' || echo "0")
PODS_MONITORING=$(kubectl get pods -n monitoring --no-headers 2>/dev/null | wc -l | tr -d ' ' || echo "0")
PODS_ARGOCD=$(kubectl get pods   -n argocd     --no-headers 2>/dev/null | wc -l | tr -d ' ' || echo "0")
PODS_SYSTEM=$(kubectl get pods   -n kube-system --no-headers 2>/dev/null | wc -l | tr -d ' ' || echo "0")

# Helm releases
HELM_RELEASES=$(helm list --all-namespaces --no-headers 2>/dev/null | \
  awk '{printf "    %-30s %-15s %s\n", $1, $2, $NF}' || echo "    (unavailable)")

# AWS resource IDs
CLUSTER_ENDPOINT=$(terraform -chdir="$TF_DIR" output -raw eks_cluster_endpoint 2>/dev/null || echo "")

# ══════════════════════════════════════════════════════════════════════════════
#  FINAL SUMMARY REPORT
# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo -e "${BOLD}${GREEN}╔══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${GREEN}║            DEPLOYMENT COMPLETE — FULL RESOURCE REPORT           ║${NC}"
echo -e "${BOLD}${GREEN}╚══════════════════════════════════════════════════════════════════╝${NC}"

# ── AWS Account ───────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}  AWS ACCOUNT${NC}"
echo    "  ┌─────────────────────────────────────────────────────────────────"
printf  "  │  %-28s %s\n" "Account ID:"   "$ACCOUNT_ID"
printf  "  │  %-28s %s\n" "Region:"       "$AWS_REGION"
echo    "  └─────────────────────────────────────────────────────────────────"

# ── Networking ────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}  NETWORKING${NC}"
echo    "  ┌─────────────────────────────────────────────────────────────────"
printf  "  │  %-28s %s\n" "VPC ID:"            "$VPC_ID"
printf  "  │  %-28s %s\n" "Availability Zones:" "${AWS_REGION}a, ${AWS_REGION}b, ${AWS_REGION}c"
printf  "  │  %-28s %s\n" "Private Subnets:"    "10.0.1.0/24, 10.0.2.0/24, 10.0.3.0/24"
printf  "  │  %-28s %s\n" "Public Subnets:"     "10.0.101.0/24, 10.0.102.0/24, 10.0.103.0/24"
printf  "  │  %-28s %s\n" "NAT Gateway:"        "1 (single, cost-optimised)"
echo    "  └─────────────────────────────────────────────────────────────────"

# ── EKS Cluster ───────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}  EKS CLUSTER${NC}"
echo    "  ┌─────────────────────────────────────────────────────────────────"
printf  "  │  %-28s %s\n" "Cluster Name:"    "$CLUSTER_NAME"
printf  "  │  %-28s %s\n" "Kubernetes Ver:"  "1.31"
printf  "  │  %-28s %s\n" "Endpoint:"        "$CLUSTER_ENDPOINT"
printf  "  │  %-28s %s\n" "Worker Nodes:"    "$NODE_COUNT (t3.medium, min 1 / max 3)"
echo    "  │"
echo    "  │  Node details:"
echo "$NODE_LIST" | while IFS= read -r line; do echo "  │    $line"; done
echo    "  └─────────────────────────────────────────────────────────────────"

# ── Container Registry ────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}  CONTAINER REGISTRY (ECR)${NC}"
echo    "  ┌─────────────────────────────────────────────────────────────────"
printf  "  │  %-28s %s\n" "Repository URL:"   "$ECR_URL"
printf  "  │  %-28s %s\n" "Scan on Push:"     "enabled"
printf  "  │  %-28s %s\n" "Image Retention:"  "last 10 images"
echo    "  └─────────────────────────────────────────────────────────────────"

# ── Redis ─────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}  ELASTICACHE REDIS${NC}"
echo    "  ┌─────────────────────────────────────────────────────────────────"
printf  "  │  %-28s %s\n" "Endpoint:"         "$REDIS_HOST"
printf  "  │  %-28s %s\n" "Node Type:"        "cache.t3.micro"
printf  "  │  %-28s %s\n" "Engine:"           "Redis 7.0"
printf  "  │  %-28s %s\n" "Encryption:"       "at-rest enabled"
echo    "  └─────────────────────────────────────────────────────────────────"

# ── SSL Certificate ───────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}  SSL CERTIFICATE (ACM)${NC}"
echo    "  ┌─────────────────────────────────────────────────────────────────"
printf  "  │  %-28s %s\n" "Certificate ARN:"  "$ACM_ARN"
printf  "  │  %-28s %s\n" "Domains:"          "sunnycharkhwalcloud.shop"
printf  "  │  %-28s %s\n" ""                  "www.sunnycharkhwalcloud.shop"
printf  "  │  %-28s %s\n" "Cost:"             "Free (AWS managed)"
echo    "  └─────────────────────────────────────────────────────────────────"

# ── Kubernetes Workloads ──────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}  KUBERNETES WORKLOADS${NC}"
echo    "  ┌─────────────────────────────────────────────────────────────────"
printf  "  │  %-28s %s\n" "portfolio namespace:"  "$PODS_PORTFOLIO pods"
printf  "  │  %-28s %s\n" "monitoring namespace:" "$PODS_MONITORING pods"
printf  "  │  %-28s %s\n" "argocd namespace:"     "$PODS_ARGOCD pods"
printf  "  │  %-28s %s\n" "kube-system:"          "$PODS_SYSTEM pods"
echo    "  └─────────────────────────────────────────────────────────────────"

# ── Helm Releases ─────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}  HELM RELEASES${NC}"
echo    "  ┌─────────────────────────────────────────────────────────────────"
echo    "  │  NAME                           NAMESPACE       STATUS"
echo "$HELM_RELEASES" | while IFS= read -r line; do echo "  │  $line"; done
echo    "  └─────────────────────────────────────────────────────────────────"

# ── CI/CD Tools ───────────────────────────────────────────────────────────────
JENKINS_STATUS="not running"
SONAR_STATUS="not running"
command -v docker &>/dev/null && {
  docker ps --format '{{.Names}}' | grep -q "^jenkins$"   && JENKINS_STATUS="running on localhost:8080"
  docker ps --format '{{.Names}}' | grep -q "^sonarqube$" && SONAR_STATUS="running on localhost:9000"
}

echo ""
echo -e "${BOLD}  CI/CD TOOLS (local Docker)${NC}"
echo    "  ┌─────────────────────────────────────────────────────────────────"
printf  "  │  %-28s %s\n" "Jenkins:"    "$JENKINS_STATUS"
printf  "  │  %-28s %s\n" "SonarQube:"  "$SONAR_STATUS"
echo    "  └─────────────────────────────────────────────────────────────────"

# ── Live URLs ─────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}  LIVE URLS${NC}"
echo    "  ┌─────────────────────────────────────────────────────────────────"
printf  "  │  %-28s %s\n" "Portfolio:"   "https://sunnycharkhwalcloud.shop"
printf  "  │  %-28s %s\n" "Grafana:"     "https://grafana.sunnycharkhwalcloud.shop"
printf  "  │  %-28s %s\n" "Jenkins:"     "http://localhost:8080"
printf  "  │  %-28s %s\n" "SonarQube:"   "http://localhost:9000"
printf  "  │  %-28s %s\n" "ArgoCD:"      "https://localhost:8443 (after port-forward)"
echo    "  └─────────────────────────────────────────────────────────────────"

# ── Load Balancers ────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}  LOAD BALANCERS (ALB)${NC}"
echo    "  ┌─────────────────────────────────────────────────────────────────"
printf  "  │  %-28s %s\n" "Portfolio ALB:" "$PORTFOLIO_ALB"
printf  "  │  %-28s %s\n" "Grafana ALB:"   "$GRAFANA_ALB"
echo    "  └─────────────────────────────────────────────────────────────────"

# ── Credentials ───────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}  CREDENTIALS${NC}"
echo    "  ┌─────────────────────────────────────────────────────────────────"
printf  "  │  %-28s %s\n" "ArgoCD user:"         "admin"
printf  "  │  %-28s %s\n" "ArgoCD password:"     "$ARGOCD_PASSWORD"
printf  "  │  %-28s %s\n" "Grafana user:"        "admin"
printf  "  │  %-28s %s\n" "Grafana password:"    "ChangeMe123!"
printf  "  │  %-28s %s\n" "SonarQube user:"      "admin"
printf  "  │  %-28s %s\n" "SonarQube password:"  "admin (change on first login)"
echo    "  └─────────────────────────────────────────────────────────────────"

# ── DNS Action Required ───────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${YELLOW}  ACTION REQUIRED — Add these DNS records to GoDaddy${NC}"
echo    "  ┌─────────────────────────────────────────────────────────────────"
echo    "  │"
echo    "  │  1. ACM certificate validation CNAMEs:"
terraform -chdir="$TF_DIR" output acm_dns_validation_records 2>/dev/null | \
  while IFS= read -r line; do echo "  │     $line"; done
echo    "  │"
echo    "  │  2. Domain A/CNAME records:"
printf  "  │     %-10s %-8s %s\n" "Type"   "Name"    "Value"
printf  "  │     %-10s %-8s %s\n" "CNAME"  "@"       "$PORTFOLIO_ALB"
printf  "  │     %-10s %-8s %s\n" "CNAME"  "www"     "$PORTFOLIO_ALB"
printf  "  │     %-10s %-8s %s\n" "CNAME"  "grafana" "$GRAFANA_ALB"
echo    "  │"
echo    "  └─────────────────────────────────────────────────────────────────"

# ── Quick Commands ────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}  USEFUL COMMANDS${NC}"
echo    "  ┌─────────────────────────────────────────────────────────────────"
echo    "  │  View pods:        kubectl get pods --all-namespaces"
echo    "  │  View ingresses:   kubectl get ingress --all-namespaces"
echo    "  │  ArgoCD UI:        kubectl port-forward svc/argocd-server -n argocd 8443:443"
echo    "  │  Grafana UI:       kubectl port-forward svc/monitoring-grafana -n monitoring 3000:80"
echo    "  │  Deploy change:    git add . && git commit -m 'msg' && git push origin main"
echo    "  │  Destroy all:      ~/sunny-portfolio/infra/scripts/destroy.sh"
echo    "  └─────────────────────────────────────────────────────────────────"
echo ""
echo -e "${BOLD}${GREEN}  Setup complete.${NC}"
echo ""
