resource "helm_release" "argo_cd" {
  name             = var.name
  namespace        = var.namespace
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.chart_version
  create_namespace = true

  # Expose the Argo CD UI/API through a LoadBalancer.
  set {
    name  = "server.service.type"
    value = "LoadBalancer"
  }
}

# Local chart that renders the Argo CD Application(s) which track the Helm chart in Git.
resource "helm_release" "argo_apps" {
  name             = "${var.name}-apps"
  chart            = "${path.module}/chart"
  namespace        = var.namespace
  create_namespace = false

  depends_on = [helm_release.argo_cd]
}
