#!/usr/bin/env bash
# =============================================================================
#  destroy.sh — Complete one-command teardown
#  Destroys ALL resources: EKS, ECR images, Redis, VPC, ACM,
#  S3 state bucket, DynamoDB lock table, local Docker containers.
#
#  Usage:  chmod +x destroy.sh && ./destroy.sh
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; NC='\033[0m'
info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
die()     { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# ── Paths ─────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INFRA_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TF_DIR="$INFRA_DIR/terraform"
TFVARS="$TF_DIR/terraform.tfvars"

[[ -f "$TFVARS" ]] || die "Cannot find $TFVARS"

# Read values directly from terraform.tfvars — no hardcoding
read_tfvar() {
  grep "^$1" "$TFVARS" | sed 's/.*=\s*//' | tr -d '"' | tr -d ' '
}

AWS_REGION=$(read_tfvar aws_region)
PROJECT_NAME=$(read_tfvar project_name)

[[ -z "$AWS_REGION" ]]   && die "aws_region not found in $TFVARS"
[[ -z "$PROJECT_NAME" ]] && die "project_name not found in $TFVARS"

# ── Confirmation ──────────────────────────────────────────────────────────────
echo ""
echo -e "${RED}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║              COMPLETE INFRASTRUCTURE TEARDOWN                ║${NC}"
echo -e "${RED}║                                                              ║${NC}"
echo -e "${RED}║  This permanently deletes:                                   ║${NC}"
echo -e "${RED}║    EKS cluster + all workloads                               ║${NC}"
echo -e "${RED}║    All ECR Docker images                                     ║${NC}"
echo -e "${RED}║    ElastiCache Redis                                         ║${NC}"
echo -e "${RED}║    VPC, subnets, NAT gateway                                 ║${NC}"
echo -e "${RED}║    ACM SSL certificate                                       ║${NC}"
echo -e "${RED}║    S3 Terraform state bucket                                 ║${NC}"
echo -e "${RED}║    DynamoDB lock table                                       ║${NC}"
echo -e "${RED}║    Jenkins + SonarQube Docker containers                     ║${NC}"
echo -e "${RED}║                                                              ║${NC}"
printf  "${RED}║  Region  : %-50s║${NC}\n" "$AWS_REGION"
printf  "${RED}║  Project : %-50s║${NC}\n" "$PROJECT_NAME"
echo -e "${RED}║                                                              ║${NC}"
echo -e "${RED}║  THIS CANNOT BE UNDONE.                                      ║${NC}"
echo -e "${RED}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
read -rp "  Type the project name '$PROJECT_NAME' to confirm: " CONFIRM

if [[ "$CONFIRM" != "$PROJECT_NAME" ]]; then
  echo "  Confirmation did not match. Aborted — nothing was deleted."
  exit 0
fi

echo ""
info "Starting teardown of $PROJECT_NAME in $AWS_REGION..."
echo ""

# ── Step 1: Remove ArgoCD Application ────────────────────────────────────────
info "[1/8] Removing ArgoCD Application..."
if command -v kubectl &>/dev/null && \
   kubectl get application sunny-portfolio -n argocd &>/dev/null 2>&1; then
  kubectl delete application sunny-portfolio -n argocd --timeout=60s 2>/dev/null || true
  success "ArgoCD Application deleted"
else
  warn "ArgoCD Application not found — skipping"
fi

# ── Step 2: Uninstall Helm releases ──────────────────────────────────────────
info "[2/8] Uninstalling Helm releases..."
if command -v helm &>/dev/null; then
  helm uninstall monitoring -n monitoring 2>/dev/null && \
    success "monitoring stack removed" || warn "monitoring not installed — skipping"

  helm uninstall aws-load-balancer-controller -n kube-system 2>/dev/null && \
    success "ALB controller removed" || warn "ALB controller not installed — skipping"
else
  warn "helm not found — skipping Helm uninstalls"
fi

# ── Step 3: Delete all ECR images ────────────────────────────────────────────
info "[3/8] Deleting ECR images..."
ECR_EXISTS=$(aws ecr describe-repositories \
  --repository-names "$PROJECT_NAME" \
  --region "$AWS_REGION" \
  --query 'repositories[0].repositoryName' \
  --output text 2>/dev/null || echo "")

if [[ -n "$ECR_EXISTS" && "$ECR_EXISTS" != "None" ]]; then
  IMAGE_IDS=$(aws ecr list-images \
    --repository-name "$PROJECT_NAME" \
    --region "$AWS_REGION" \
    --query 'imageIds' \
    --output json 2>/dev/null || echo "[]")

  if [[ "$IMAGE_IDS" != "[]" ]]; then
    aws ecr batch-delete-image \
      --repository-name "$PROJECT_NAME" \
      --region "$AWS_REGION" \
      --image-ids "$IMAGE_IDS" \
      --output text &>/dev/null 2>&1 || true
    success "ECR images deleted"
  else
    warn "No ECR images to delete"
  fi
else
  warn "ECR repository not found — skipping"
fi

# ── Step 4: Terraform destroy ─────────────────────────────────────────────────
info "[4/8] Running terraform destroy (takes ~10 minutes)..."
cd "$TF_DIR"

if [[ -f ".terraform/terraform.tfstate" ]] || \
   aws s3 ls "s3://sunny-portfolio-tfstate/eks/terraform.tfstate" \
     --region "$AWS_REGION" &>/dev/null 2>&1; then
  terraform init -input=false -no-color 2>/dev/null
  terraform destroy -auto-approve -no-color 2>&1 | \
    grep -E "Destroy complete|destroyed|Error|error" || true
  success "Terraform resources destroyed"
else
  warn "No Terraform state found — skipping terraform destroy"
fi

# ── Step 5: Delete S3 state bucket ───────────────────────────────────────────
info "[5/8] Deleting S3 state bucket..."
BUCKET="sunny-portfolio-tfstate"

if aws s3api head-bucket --bucket "$BUCKET" \
   --region "$AWS_REGION" &>/dev/null 2>&1; then

  # Remove all objects
  aws s3 rm "s3://$BUCKET" --recursive \
    --region "$AWS_REGION" 2>/dev/null || true

  # Remove versioned objects
  VERSIONS=$(aws s3api list-object-versions \
    --bucket "$BUCKET" \
    --region "$AWS_REGION" \
    --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' \
    --output json 2>/dev/null || echo '{"Objects":null}')

  if [[ "$VERSIONS" != '{"Objects":null}' ]]; then
    aws s3api delete-objects \
      --bucket "$BUCKET" \
      --region "$AWS_REGION" \
      --delete "$VERSIONS" &>/dev/null 2>&1 || true
  fi

  # Remove delete markers
  MARKERS=$(aws s3api list-object-versions \
    --bucket "$BUCKET" \
    --region "$AWS_REGION" \
    --query '{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}' \
    --output json 2>/dev/null || echo '{"Objects":null}')

  if [[ "$MARKERS" != '{"Objects":null}' ]]; then
    aws s3api delete-objects \
      --bucket "$BUCKET" \
      --region "$AWS_REGION" \
      --delete "$MARKERS" &>/dev/null 2>&1 || true
  fi

  aws s3 rb "s3://$BUCKET" --region "$AWS_REGION" 2>/dev/null && \
    success "S3 state bucket deleted" || \
    warn "S3 bucket could not be deleted (may already be gone)"
else
  warn "S3 bucket not found — skipping"
fi

# ── Step 6: Delete DynamoDB lock table ───────────────────────────────────────
info "[6/8] Deleting DynamoDB lock table..."
if aws dynamodb describe-table \
   --table-name "sunny-portfolio-tf-lock" \
   --region "$AWS_REGION" &>/dev/null 2>&1; then
  aws dynamodb delete-table \
    --table-name "sunny-portfolio-tf-lock" \
    --region "$AWS_REGION" &>/dev/null
  success "DynamoDB table deleted"
else
  warn "DynamoDB table not found — skipping"
fi

# ── Step 7: Stop local Docker containers ─────────────────────────────────────
info "[7/8] Stopping local Docker containers..."
if command -v docker &>/dev/null; then
  for CONTAINER in jenkins sonarqube; do
    if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
      docker stop "$CONTAINER" 2>/dev/null || true
      docker rm   "$CONTAINER" 2>/dev/null || true
      success "$CONTAINER removed"
    else
      warn "$CONTAINER not running — skipping"
    fi
  done
  docker volume rm jenkins_home 2>/dev/null && \
    success "jenkins_home volume removed" || \
    warn "jenkins_home volume not found"
else
  warn "Docker not found — skipping container cleanup"
fi

# ── Step 8: Clean local Terraform state ──────────────────────────────────────
info "[8/8] Cleaning local Terraform files..."
rm -f  "$TF_DIR/.terraform.lock.hcl"
rm -f  "$TF_DIR/terraform.tfstate"
rm -f  "$TF_DIR/terraform.tfstate.backup"
rm -rf "$TF_DIR/.terraform"
rm -f  "$INFRA_DIR/terraform/bootstrap/.terraform.lock.hcl"
rm -rf "$INFRA_DIR/terraform/bootstrap/.terraform"
rm -f  "$INFRA_DIR/../.deploy-env"
success "Local state cleaned"

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                   TEARDOWN COMPLETE                         ║${NC}"
echo -e "${GREEN}║                                                              ║${NC}"
echo -e "${GREEN}║  All AWS resources have been deleted.                        ║${NC}"
echo -e "${GREEN}║  Your code at ~/sunny-portfolio is untouched.                ║${NC}"
echo -e "${GREEN}║                                                              ║${NC}"
echo -e "${GREEN}║  To redeploy from scratch:                                   ║${NC}"
echo -e "${GREEN}║    cd ~/sunny-portfolio/infra/terraform/bootstrap            ║${NC}"
echo -e "${GREEN}║    terraform init && terraform apply -auto-approve           ║${NC}"
echo -e "${GREEN}║    cd ..                                                     ║${NC}"
echo -e "${GREEN}║    terraform init && terraform apply -auto-approve           ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
