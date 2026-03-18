# ============================================================
# outputs.tf — Everything you need to know after apply
# ============================================================

output "STEP_1_godaddy_nameservers" {
  description = ">>> IMPORTANT: Paste these 4 NS values into GoDaddy DNS panel <<<"
  value       = aws_route53_zone.main.name_servers
}

output "STEP_2_site_url" {
  description = "Your live website URL (available after DNS propagates, ~5 min)"
  value       = "https://${var.domain_name}"
}

output "STEP_3_www_url" {
  value = "https://www.${var.domain_name}"
}

output "cloudfront_distribution_id" {
  description = "Use this to invalidate CloudFront cache after each deploy"
  value       = aws_cloudfront_distribution.app.id
}

output "ecr_repo_url" {
  description = "Docker push target for the CI pipeline"
  value       = aws_ecr_repository.app.repository_url
}

output "eks_cluster_name" {
  value = aws_eks_cluster.main.name
}

output "eks_cluster_endpoint" {
  value = aws_eks_cluster.main.endpoint
}

output "kubeconfig_command" {
  description = "Run this to configure kubectl on your machine"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${var.eks_cluster_name}"
}

output "jenkins_ip" {
  description = "Jenkins CI server — open http://<ip>:8080 in your browser"
  value       = aws_instance.jenkins.public_ip
}

output "jenkins_ssh_command" {
  value = "ssh -i ~/.ssh/jenkins-key ec2-user@${aws_instance.jenkins.public_ip}"
}

output "jenkins_initial_admin_password" {
  description = "Get initial Jenkins password with this command"
  value       = "ssh -i ~/.ssh/jenkins-key ec2-user@${aws_instance.jenkins.public_ip} 'sudo cat /var/lib/jenkins/secrets/initialAdminPassword'"
}

output "sonarqube_url" {
  description = "SonarQube dashboard — default login: admin / admin"
  value       = "http://${aws_instance.sonarqube.public_ip}:9000"
}

output "redis_endpoint" {
  description = "Redis primary endpoint (accessible from EKS pods)"
  value       = aws_elasticache_replication_group.redis.primary_endpoint_address
}

output "alb_dns" {
  value = aws_lb.app.dns_name
}

output "aws_region_used" {
  description = "Confirms which region ALL resources were deployed to"
  value       = var.aws_region
}

output "account_id" {
  value = data.aws_caller_identity.current.account_id
}

# ── What WAS created ─────────────────────────────────────────
output "RESOURCES_CREATED" {
  description = "Full list of what Terraform created"
  value = {
    networking   = "VPC, 3 public subnets, 3 private subnets, 3 NAT gateways, IGW, route tables"
    compute      = "EKS cluster (v1.29), managed node group (${var.eks_node_instance_type} × ${var.eks_desired_nodes} nodes)"
    ci_server    = "Jenkins EC2 (t3.large) at ${aws_instance.jenkins.public_ip}:8080"
    code_quality = "SonarQube EC2 (t3.medium) at ${aws_instance.sonarqube.public_ip}:9000"
    registry     = "ECR repo: ${aws_ecr_repository.app.repository_url}"
    caching      = "ElastiCache Redis 7.1 (${var.redis_node_type}, multi-AZ)"
    cdn          = "CloudFront distribution → ALB → EKS"
    ssl          = "ACM free wildcard cert for *.${var.domain_name} (auto-renewed)"
    dns          = "Route 53 hosted zone for ${var.domain_name}"
    cd           = "ArgoCD (GitOps) installed via Helm in argocd namespace"
    monitoring   = "Prometheus + Grafana (kube-prometheus-stack) in monitoring namespace"
    lb           = "AWS Load Balancer Controller (Ingress → ALB)"
  }
}

# ── What was NOT created ─────────────────────────────────────
output "RESOURCES_NOT_CREATED" {
  description = "Intentionally out of scope"
  value = {
    not_created = [
      "S3 bucket for Terraform state (optional — uncomment backend block in main.tf)",
      "RDS database (portfolio app is stateless, only uses Redis caching)",
      "WAF (Web Application Firewall) — add manually if needed",
      "Shield Advanced DDoS protection — paid; add manually",
      "Route53 health checks / failover routing — simple alias used instead",
      "Bastion host — use SSM Session Manager instead for security",
      "Jenkins backup / EBS snapshot policy",
      "SonarQube persistent DB (uses embedded H2 — fine for dev, use RDS for prod)",
    ]
  }
}
