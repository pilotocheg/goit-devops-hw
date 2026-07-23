variable "github_username" {
  description = "GitHub username for the Jenkins 'github-token' credential"
  type        = string
  default     = "pilotocheg"
}

variable "github_pat" {
  description = "GitHub PAT (Contents: read/write) used by Jenkins to push Helm chart tag updates. Provide via TF_VAR_github_pat env var or a gitignored terraform.tfvars."
  type        = string
  sensitive   = true
}

variable "rds_password" {
  description = "Optional RDS master password. Leave null to auto-generate one in the module. To set explicitly, prefer the TF_VAR_rds_password env var over committing it."
  type        = string
  default     = null
  sensitive   = true
}

variable "grafana_admin_password" {
  description = "Grafana admin password for the monitoring stack. Provide via TF_VAR_grafana_admin_password env var or terraform.tfvars."
  type        = string
  sensitive   = true
}
