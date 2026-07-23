resource "helm_release" "kube_prometheus_stack" {
  name             = var.release_name
  namespace        = var.namespace
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = var.chart_version
  create_namespace = true

  # Expose Grafana via LoadBalancer so it is reachable outside the cluster.
  set {
    name  = "grafana.service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "grafana.adminPassword"
    value = var.grafana_admin_password
  }

  # Keep metrics for 7 days (suitable for a demo/dev cluster).
  set {
    name  = "prometheus.prometheusSpec.retention"
    value = "7d"
  }

  # Persist Prometheus data on an EBS volume so metrics survive pod restarts.
  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.accessModes[0]"
    value = "ReadWriteOnce"
  }

  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage"
    value = var.prometheus_storage_size
  }
}
