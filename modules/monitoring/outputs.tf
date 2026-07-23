output "grafana_service_name" {
  description = "Kubernetes Service name for the Grafana LoadBalancer"
  value       = "${helm_release.kube_prometheus_stack.name}-grafana"
}

output "prometheus_service_name" {
  description = "Kubernetes Service name for Prometheus"
  value       = "${helm_release.kube_prometheus_stack.name}-kube-promethe-prometheus"
}

output "release_name" {
  description = "Helm release name"
  value       = helm_release.kube_prometheus_stack.name
}

output "namespace" {
  description = "Namespace where the monitoring stack is deployed"
  value       = helm_release.kube_prometheus_stack.namespace
}
