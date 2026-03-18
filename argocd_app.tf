# ============================================================
# argocd_app.tf — ArgoCD Application (GitOps CD)
# ============================================================

resource "kubectl_manifest" "argocd_app" {
  yaml_body = <<-YAML
    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: ${var.project_name}
      namespace: argocd
      finalizers:
        - resources-finalizer.argocd.argoproj.io
    spec:
      project: default
      source:
        repoURL: ${var.github_repo}
        targetRevision: ${var.github_branch}
        path: k8s
      destination:
        server: https://kubernetes.default.svc
        namespace: ${var.project_name}
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
  YAML

  depends_on = [helm_release.argocd, kubernetes_namespace.app]
}
