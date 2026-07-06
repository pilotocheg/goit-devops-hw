terraform {
  backend "s3" {
    bucket       = "terraform-demo-bucket-683210040028"
    key          = "terraform-demo/terraform.tfstate"
    region       = "eu-central-1"
    use_lockfile = true
    encrypt      = true
  }
}