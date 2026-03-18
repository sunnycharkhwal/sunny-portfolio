variable "cluster_endpoint" {}
variable "cluster_ca" {}
variable "cluster_name" {}

output "cluster_endpoint" { value = var.cluster_endpoint }
output "cluster_ca"       { value = var.cluster_ca }
output "cluster_name"     { value = var.cluster_name }
