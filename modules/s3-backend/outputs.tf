output "s3_bucket_name" {
  description = "Назва S3-бакета для стейтів"
  value       = aws_s3_bucket.terraform_state.bucket
}
