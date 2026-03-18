#!/bin/bash
# ============================================================
# scripts/jenkins_bootstrap.sh
# Bootstraps Jenkins + Docker + kubectl + Trivy + OWASP tools
# on Amazon Linux 2023
# ============================================================
set -euxo pipefail

AWS_REGION="${aws_region}"
ECR_REPO_URL="${ecr_repo_url}"
EKS_CLUSTER_NAME="${eks_cluster_name}"

# ── System updates ────────────────────────────────────────────
dnf update -y
dnf install -y git curl wget unzip tar

# ── Java 17 (required by Jenkins) ────────────────────────────
dnf install -y java-17-amazon-corretto

# ── Jenkins ──────────────────────────────────────────────────
wget -O /etc/yum.repos.d/jenkins.repo \
  https://pkg.jenkins.io/redhat-stable/jenkins.repo
rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
dnf install -y jenkins
systemctl enable jenkins
systemctl start jenkins

# ── Docker ───────────────────────────────────────────────────
dnf install -y docker
systemctl enable docker
systemctl start docker
usermod -aG docker jenkins
usermod -aG docker ec2-user

# ── AWS CLI v2 ────────────────────────────────────────────────
curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
unzip /tmp/awscliv2.zip -d /tmp
/tmp/aws/install
rm -rf /tmp/awscliv2.zip /tmp/aws

# ── kubectl ───────────────────────────────────────────────────
curl -fsSL "https://dl.k8s.io/release/$(curl -fsSL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
  -o /usr/local/bin/kubectl
chmod +x /usr/local/bin/kubectl

# ── Helm ─────────────────────────────────────────────────────
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# ── Trivy (filesystem / image vulnerability scanner) ─────────
rpm --import https://aquasecurity.github.io/trivy-repo/rpm/public.key
cat > /etc/yum.repos.d/trivy.repo <<'EOF'
[trivy]
name=Trivy repository
baseurl=https://aquasecurity.github.io/trivy-repo/rpm/releases/$releasever/$basearch/
gpgcheck=1
enabled=1
gpgkey=https://aquasecurity.github.io/trivy-repo/rpm/public.key
EOF
dnf install -y trivy

# ── OWASP Dependency Check CLI ───────────────────────────────
OWASP_VERSION="9.1.0"
wget -q "https://github.com/jeremylong/DependencyCheck/releases/download/v${OWASP_VERSION}/dependency-check-${OWASP_VERSION}-release.zip" \
  -O /tmp/dependency-check.zip
unzip /tmp/dependency-check.zip -d /opt/
ln -sf /opt/dependency-check/bin/dependency-check.sh /usr/local/bin/dependency-check
rm /tmp/dependency-check.zip

# ── ArgoCD CLI ───────────────────────────────────────────────
curl -sSL -o /usr/local/bin/argocd \
  https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x /usr/local/bin/argocd

# ── Configure kubectl for EKS ────────────────────────────────
aws eks update-kubeconfig \
  --region "$AWS_REGION" \
  --name "$EKS_CLUSTER_NAME" \
  --kubeconfig /var/lib/jenkins/.kube/config

mkdir -p /var/lib/jenkins/.kube
chown -R jenkins:jenkins /var/lib/jenkins/.kube

# ── Write ECR login helper for Jenkins ───────────────────────
cat > /etc/profile.d/ecr_login.sh <<EOF
#!/bin/bash
aws ecr get-login-password --region ${AWS_REGION} | \
  docker login --username AWS --password-stdin ${ECR_REPO_URL}
EOF
chmod +x /etc/profile.d/ecr_login.sh

echo "=== Jenkins bootstrap complete ==="
echo "Jenkins initial password: $(cat /var/lib/jenkins/secrets/initialAdminPassword 2>/dev/null || echo 'still starting...')"
