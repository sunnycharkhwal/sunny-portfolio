variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Project name — used to name all resources"
  type        = string
  default     = "sunny-portfolio"
}

variable "environment" {
  description = "Environment label"
  type        = string
  default     = "production"
}

variable "domain" {
  description = "Your primary domain (no www prefix)"
  type        = string
  default     = "sunnycharkhwalcloud.shop"
}

variable "node_instance_type" {
  description = "EC2 instance type for EKS worker nodes"
  type        = string
  default     = "t3.medium"
}
