provider "aws" {
  region = "eu-central-1"
}

module "s3_backend" {
  source = "./modules/s3-backend"
  bucket_name = "terraform-demo-bucket"
  table_name = "terraform-demo-locks"
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
  subnet_ids      = module.vpc.private_subnets     # ID підмереж
  instance_type   = "t3.micro"                    # Тип інстансів
  desired_size    = 1                             # Бажана кількість нодів
  max_size        = 2                             # Максимальна кількість нодів
  min_size        = 1                             # Мінімальна кількість нодів
}

data "aws_eks_cluster" "eks" {
  name = module.eks.eks_cluster_name
}

data "aws_eks_cluster_auth" "eks" {
  name = module.eks.eks_cluster_name
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.eks.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.eks.token
  }
}

module "jenkins" {
  source       = "./modules/jenkins"
  cluster_name = module.eks.eks_cluster_name

  providers = {
    helm = helm
  }
}
