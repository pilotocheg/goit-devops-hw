output "endpoint" {
  description = "Connection endpoint (writer endpoint for Aurora)"
  value       = var.use_aurora ? aws_rds_cluster.aurora[0].endpoint : aws_db_instance.standard[0].address
}

output "reader_endpoint" {
  description = "Aurora reader endpoint (null for standard RDS)"
  value       = var.use_aurora ? aws_rds_cluster.aurora[0].reader_endpoint : null
}

output "port" {
  description = "Port the DB is listening on"
  value       = local.db_port
}

output "db_name" {
  description = "Name of the initial database"
  value       = var.db_name
}

output "username" {
  description = "Master username"
  value       = var.username
}

output "password" {
  description = "Master password (generated when not provided)"
  value       = local.master_password
  sensitive   = true
}

output "security_group_id" {
  description = "ID of the DB security group"
  value       = aws_security_group.rds.id
}
