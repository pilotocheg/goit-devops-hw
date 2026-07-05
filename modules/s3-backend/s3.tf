resource "aws_s3_bucket" "terraform_state" {
  bucket = var.bucket_name

  # Allow `terraform destroy` to delete the bucket even if it still contains
  # state object versions. Convenient for a demo/teardown; remove for production.
  force_destroy = true

  tags = {
    Name        = "Terraform State Bucket"
    Environment = "terraform-demo"
  }
}

resource "aws_s3_bucket_versioning" "terraform_state_versioning" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_ownership_controls" "terraform_state_ownership" {
  bucket = aws_s3_bucket.terraform_state.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}