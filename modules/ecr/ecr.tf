resource "aws_ecr_repository" "ecr" {
  name = var.ecr_name

  # Allow `terraform destroy` to delete the repository even if it still holds images.
  force_delete = true

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  tags = {
    Name = var.ecr_name
  }
}