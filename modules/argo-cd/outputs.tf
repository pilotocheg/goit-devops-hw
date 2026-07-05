output "argocd_namespace" {
  description = "Namespace, у якому встановлено Argo CD"
  value       = var.namespace
}

output "argocd_server_lb_hint" {
  description = "Команда для отримання адреси LoadBalancer сервера Argo CD"
  value       = "kubectl -n ${var.namespace} get svc ${var.name}-argocd-server -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
}

output "admin_password_hint" {
  description = "Команда для отримання початкового пароля адміністратора Argo CD"
  value       = "kubectl -n ${var.namespace} get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
}
