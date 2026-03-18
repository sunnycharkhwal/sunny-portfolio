output "ecr_repository_url" {
  description = "ECR URL — paste into helm/portfolio/values.yaml image.repository"
  value       = aws_ecr_repository.portfolio.repository_url
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS API server endpoint"
  value       = module.eks.cluster_endpoint
}

output "redis_endpoint" {
  description = "Redis endpoint — paste into helm/portfolio/values.yaml redis.externalEndpoint"
  value       = aws_elasticache_replication_group.redis.primary_endpoint_address
}

output "acm_certificate_arn" {
  description = "ACM ARN — paste into helm/portfolio/values.yaml and helm/monitoring/values.yaml"
  value       = aws_acm_certificate.portfolio.arn
}

output "acm_dns_validation_records" {
  description = "Add these CNAMEs to GoDaddy DNS to validate the SSL certificate"
  value = {
    for dvo in aws_acm_certificate.portfolio.domain_validation_options :
    dvo.domain_name => {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  }
}

output "aws_region" {
  description = "Region everything was deployed to"
  value       = var.aws_region
}

output "kubeconfig_command" {
  description = "Run this to connect kubectl to your cluster"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "vpc_id" {
  value = module.vpc.vpc_id
}
