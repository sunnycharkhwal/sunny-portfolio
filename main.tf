# ============================================================
# main.tf — Provider configuration + Terraform backend
# ============================================================

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.27"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
  }

  # ── Optional: remote state in S3 (comment out if using local state) ──
  # backend "s3" {
  #   bucket         = "sunny-terraform-state"
  #   key            = "sunny-portfolio/terraform.tfstate"
  #   region         = "us-east-1"   # backend bucket region (fixed)
  #   dynamodb_table = "sunny-terraform-locks"
  #   encrypt        = true
  # }
}

# ────────────────────────────────────────────────────────────
# AWS Provider — region driven by var.aws_region (single source of truth)
# ────────────────────────────────────────────────────────────
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Region      = var.aws_region
    }
  }
}

# ACM certificates for CloudFront MUST be in us-east-1.
# This aliased provider handles that automatically.
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# ────────────────────────────────────────────────────────────
# Kubernetes & Helm providers — wired to the EKS cluster output
# ────────────────────────────────────────────────────────────
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_ca)
  token                  = data.aws_eks_cluster_auth.main.token
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_ca)
    token                  = data.aws_eks_cluster_auth.main.token
  }
}

provider "kubectl" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_ca)
  token                  = data.aws_eks_cluster_auth.main.token
  load_config_file       = false
}

# ────────────────────────────────────────────────────────────
# Data sources
# ────────────────────────────────────────────────────────────
data "aws_eks_cluster_auth" "main" {
  name = module.eks.cluster_name
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}
