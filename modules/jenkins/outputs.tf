output "jenkins_release_name" {
  value = helm_release.jenkins.name
}

output "jenkins_namespace" {
  value = helm_release.jenkins.namespace
}

output "jenkins_admin_password" {
  description = "Generated Jenkins admin password"
  value       = random_password.jenkins_admin.result
  sensitive   = true
}
