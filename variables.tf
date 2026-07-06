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
