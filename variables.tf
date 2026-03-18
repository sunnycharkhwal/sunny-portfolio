# ============================================================
# variables.tf — All configurable inputs in ONE place.
# Change a value here and it propagates everywhere.
# ============================================================

variable "aws_region" {
  description = "AWS region for ALL resources (change once → applies everywhere)"
  type        = string
  default     = "us-east-1"   # ← Change this ONE line to move everything to another region
}

variable "domain_name" {
  description = "Root domain (GoDaddy / Route 53)"
  type        = string
  default     = "sunnycharkhwalcloud.shop"
}

variable "subdomain" {
  description = "Subdomain to use. Leave empty to use the apex domain."
  type        = string
  default     = "www"   # result → www.sunnycharkhwalcloud.shop
}

variable "github_repo" {
  description = "GitHub repository URL for the portfolio app"
  type        = string
  default     = "https://github.com/sunnycharkhwal/sunny-portfolio.git"
}

variable "github_branch" {
  description = "Git branch to deploy"
  type        = string
  default     = "main"
}

variable "eks_cluster_name" {
  description = "Name for the EKS cluster"
  type        = string
  default     = "sunny-portfolio-cluster"
}

variable "eks_node_instance_type" {
  description = "EC2 instance type for EKS worker nodes"
  type        = string
  default     = "t3.medium"
}

variable "eks_desired_nodes" {
  description = "Desired number of EKS worker nodes"
  type        = number
  default     = 2
}

variable "eks_min_nodes" {
  description = "Minimum EKS worker nodes"
  type        = number
  default     = 1
}

variable "eks_max_nodes" {
  description = "Maximum EKS worker nodes"
  type        = number
  default     = 4
}

variable "ecr_repo_name" {
  description = "ECR repository name for the Docker image"
  type        = string
  default     = "sunny-portfolio"
}

variable "redis_node_type" {
  description = "ElastiCache Redis node type"
  type        = string
  default     = "cache.t3.micro"
}

variable "environment" {
  description = "Environment tag (prod / staging / dev)"
  type        = string
  default     = "prod"
}

variable "project_name" {
  description = "Project name used for tagging and naming all resources"
  type        = string
  default     = "sunny-portfolio"
}

variable "alert_email" {
  description = "Email for cost/alarm notifications"
  type        = string
  default     = "sunny@example.com"   # ← Change to your real email
}
