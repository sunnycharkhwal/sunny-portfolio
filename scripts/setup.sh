#!/bin/bash
# scripts/setup.sh
# Run once after terraform apply to bootstrap the EKS cluster.
# Usage: ./scripts/setup.sh
set -euo pipefail

AWS_REGION="ap-south-1"
CLUSTER_NAME="sunny-portfolio"

echo ""
echo "=========================================="
echo " Sunny Portfolio — Cluster Bootstrap"
echo "=========================================="
echo ""

# ── Step 1: Connect kubectl ────────────────────────────────────────────────────
echo "[1/6] Configuring kubectl..."
aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"
kubectl cluster-info
echo ""

# ── Step 2: Install ArgoCD ────────────────────────────────────────────────────
echo "[2/6] Installing ArgoCD..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "Waiting for ArgoCD server to be ready (up to 3 minutes)..."
kubectl wait --for=condition=available deployment/argocd-server \
  -n argocd --timeout=180s

ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d)
echo "ArgoCD admin password: $ARGOCD_PASSWORD"
echo ""

# ── Step 3: Install Prometheus + Grafana ─────────────────────────────────────
echo "[3/6] Installing monitoring stack (Prometheus + Grafana)..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install monitoring \
  prometheus-community/kube-prometheus-stack \
  --values helm/monitoring/values.yaml \
  --namespace monitoring \
  --create-namespace \
  --wait \
  --timeout 10m
echo ""

# ── Step 4: Apply ArgoCD Application ─────────────────────────────────────────
echo "[4/6] Applying ArgoCD Application manifest..."
kubectl apply -f argocd/application.yaml
echo ""

# ── Step 5: Wait for ALB and print DNS name ───────────────────────────────────
echo "[5/6] Waiting 90s for ALB to provision..."
sleep 90

ALB_DNS=$(kubectl get ingress \
  -n portfolio \
  -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}' \
  2>/dev/null || echo "not-provisioned-yet")

GRAFANA_ALB=$(kubectl get ingress \
  -n monitoring \
  -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}' \
  2>/dev/null || echo "not-provisioned-yet")
echo ""

# ── Step 6: Print summary ─────────────────────────────────────────────────────
echo "[6/6] Bootstrap complete. Summary:"
echo ""
echo "  Portfolio ALB DNS : $ALB_DNS"
echo "  Grafana ALB DNS   : $GRAFANA_ALB"
echo ""
echo "  Add these CNAME records to GoDaddy DNS:"
echo "  ┌──────────────────────────────────────────────────────────────┐"
echo "  │  Type   Name   Value                                         │"
echo "  │  CNAME  @      $ALB_DNS  │"
echo "  │  CNAME  www    $ALB_DNS  │"
echo "  └──────────────────────────────────────────────────────────────┘"
echo ""
echo "  ArgoCD UI (run in a new terminal):"
echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "  Open: https://localhost:8080  |  user: admin  |  pass: $ARGOCD_PASSWORD"
echo ""
echo "  Grafana: https://grafana.sunnycharkhwalcloud.shop"
echo "  Login  : admin / ChangeMe123!"
echo ""
echo "  Portfolio: https://sunnycharkhwalcloud.shop"
echo "  (live once GoDaddy DNS propagates, usually 5-30 minutes)"
echo ""
echo "=========================================="
