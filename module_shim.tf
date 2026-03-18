# ============================================================
# module_shim.tf
# The providers in main.tf reference module.eks.* — this local
# module simply re-exports the eks.tf outputs so the provider
# configuration block can resolve them before apply.
# ============================================================

module "eks" {
  source = "./modules/eks_shim"

  cluster_endpoint = aws_eks_cluster.main.endpoint
  cluster_ca       = aws_eks_cluster.main.certificate_authority[0].data
  cluster_name     = aws_eks_cluster.main.name
}
