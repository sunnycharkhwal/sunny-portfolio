#!/bin/bash
# ============================================================
# scripts/sonarqube_bootstrap.sh
# Installs SonarQube Community Edition via Docker
# ============================================================
set -euxo pipefail

# ── System prep ───────────────────────────────────────────────
dnf update -y
dnf install -y docker
systemctl enable docker
systemctl start docker

# ── Kernel settings required by SonarQube / Elasticsearch ────
sysctl -w vm.max_map_count=524288
sysctl -w fs.file-max=131072
echo "vm.max_map_count=524288" >> /etc/sysctl.conf
echo "fs.file-max=131072"      >> /etc/sysctl.conf

ulimit -n 131072
ulimit -u 8192

# ── Run SonarQube in Docker ───────────────────────────────────
docker run -d \
  --name sonarqube \
  --restart unless-stopped \
  -p 9000:9000 \
  -e SONAR_ES_BOOTSTRAP_CHECKS_DISABLE=true \
  -v sonarqube_data:/opt/sonarqube/data \
  -v sonarqube_logs:/opt/sonarqube/logs \
  -v sonarqube_extensions:/opt/sonarqube/extensions \
  sonarqube:community

echo "=== SonarQube starting at http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):9000 ==="
echo "Default login: admin / admin (change on first login)"
