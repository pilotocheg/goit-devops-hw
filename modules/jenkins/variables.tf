variable "cluster_name" {
  description = "Назва Kubernetes кластера"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the EKS OIDC provider (for IRSA)"
  type        = string
}

variable "oidc_provider_url" {
  description = "URL of the EKS OIDC provider (for IRSA)"
  type        = string
}

variable "ecr_repository_arn" {
  description = "ARN of the ECR repository Jenkins/Kaniko pushes to"
  type        = string
}

variable "github_username" {
  description = "GitHub username for the Jenkins 'github-token' credential"
  type        = string
  default     = "pilotocheg"
}

variable "github_pat" {
  description = "GitHub PAT (Contents: read/write) for the Jenkins 'github-token' credential used to push Helm chart tag updates"
  type        = string
  sensitive   = true
}
