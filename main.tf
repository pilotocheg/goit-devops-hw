provider "aws" {
  region = "eu-central-1"
}

data "aws_caller_identity" "current" {}

module "s3_backend" {
  source = "./modules/s3-backend"
  bucket_name = "terraform-demo-bucket-${data.aws_caller_identity.current.account_id}"
}

module "vpc" {
  source = "./modules/vpc"
  vpc_cidr_block = "10.0.0.0/16"
  public_subnets      = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnets     = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  availability_zones  = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
  vpc_name = "terraform-demo-vpc"
}

module "ecr" {
  source      = "./modules/ecr"
  ecr_name    = "terraform-demo-ecr"
  scan_on_push = true
}

module "eks" {
  source          = "./modules/eks"
  region          = "eu-central-1"
  cluster_name    = "eks-cluster-demo"            # Назва кластера
  subnet_ids      = module.vpc.public_subnets      # ID підмереж (public, щоб ноди мали вихід в інтернет через IGW)
  instance_type   = "t3.small"                    # Тип інстансів (t3.micro дає лише 4 поди на ноду — замало для CSI + Jenkins)
  desired_size    = 2                             # Бажана кількість нодів
  max_size        = 3                             # Максимальна кількість нодів
  min_size        = 1                             # Мінімальна кількість нодів
}

data "aws_eks_cluster_auth" "eks" {
  name = module.eks.eks_cluster_name
}

provider "helm" {
  kubernetes {
    host                   = module.eks.eks_cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.eks_cluster_certificate_authority)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.eks_cluster_name, "--region", "eu-central-1"]
    }
  }
}

provider "kubernetes" {
  host                   = module.eks.eks_cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.eks_cluster_certificate_authority)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.eks_cluster_name, "--region", "eu-central-1"]
  }
}

module "jenkins" {
  source             = "./modules/jenkins"
  cluster_name       = module.eks.eks_cluster_name
  oidc_provider_arn  = module.eks.oidc_provider_arn
  oidc_provider_url  = module.eks.oidc_provider_url
  ecr_repository_arn = module.ecr.ecr_repository_arn

  providers = {
    helm       = helm
    kubernetes = kubernetes
  }
}
