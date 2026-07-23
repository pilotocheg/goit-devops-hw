variable "release_name" {
  description = "Helm release name for kube-prometheus-stack"
  type        = string
  default     = "kube-prometheus-stack"
}

variable "namespace" {
  description = "Kubernetes namespace for the monitoring stack"
  type        = string
  default     = "monitoring"
}

variable "chart_version" {
  description = "Version of the kube-prometheus-stack Helm chart"
  type        = string
  default     = "61.7.2"
}

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
}

variable "prometheus_storage_size" {
  description = "PVC size for Prometheus data (e.g. '10Gi')"
  type        = string
  default     = "10Gi"
}
