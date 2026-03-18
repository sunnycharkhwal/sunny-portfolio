# ============================================================
# terraform.tfvars — Your personal values
# This file is NOT committed to git (.gitignore includes it)
# ============================================================

# ── Single source of truth for region ────────────────────────
# Change this ONE value → every resource moves to the new region
aws_region = "us-east-1"

# ── Domain ────────────────────────────────────────────────────
domain_name = "sunnycharkhwalcloud.shop"
subdomain   = "www"

# ── GitHub ────────────────────────────────────────────────────
github_repo   = "https://github.com/sunnycharkhwal/sunny-portfolio.git"
github_branch = "main"

# ── EKS ───────────────────────────────────────────────────────
eks_cluster_name       = "sunny-portfolio-cluster"
eks_node_instance_type = "t3.medium"
eks_desired_nodes      = 2
eks_min_nodes          = 1
eks_max_nodes          = 4

# ── ECR ───────────────────────────────────────────────────────
ecr_repo_name = "sunny-portfolio"

# ── Redis ─────────────────────────────────────────────────────
redis_node_type = "cache.t3.micro"

# ── Tagging ───────────────────────────────────────────────────
environment  = "prod"
project_name = "sunny-portfolio"
alert_email  = "sunny@example.com"   # ← Your real email for alerts
