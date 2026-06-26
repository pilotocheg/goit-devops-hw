output "s3_bucket_name" {
  description = "S3 bucket for state storage"
  value = module.s3_backend.s3_bucket_name
}

output "dynamodb_table_name" {
  description = "DynamoDB table for state locking"
  value = module.s3_backend.dynamodb_table_name
}