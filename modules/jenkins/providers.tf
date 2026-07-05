terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.10, < 3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.20, < 3.0"
    }
  }
}
