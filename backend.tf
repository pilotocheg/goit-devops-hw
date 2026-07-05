terraform {
  backend "s3" {
    bucket         = "terraform-demo-bucket"
    key            = "terraform-demo/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "terraform-demo-locks"
    encrypt        = true
  }
}