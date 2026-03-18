#!/bin/bash
# scripts/destroy.sh
# Safely tears down the EKS cluster and all AWS resources.
# WARNING: This deletes everything and cannot be undone.
set -euo pipefail

AWS_REGION="ap-south-1"
CLUSTER_NAME="sunny-portfolio"

echo ""
echo "WARNING: This will DELETE the entire cluster and all AWS resources."
read -rp "Type 'yes' to confirm: " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
  echo "Aborted."
  exit 1
fi

echo ""
echo "[1/3] Connecting kubectl..."
aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME" 2>/dev/null || true

echo "[2/3] Deleting ArgoCD Application (removes portfolio namespace)..."
kubectl delete application sunny-portfolio -n argocd 2>/dev/null || true

echo "[3/3] Running terraform destroy..."
cd terraform
terraform destroy -auto-approve

echo ""
echo "All resources destroyed."
