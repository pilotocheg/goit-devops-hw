output "s3_bucket_name" {
  description = "S3 bucket for state storage"
  value       = module.s3_backend.s3_bucket_name
}

#-------------VPC-----------------

output "vpc_id" {
  description = "ID of the created VPC"
  value       = module.vpc.vpc_id
}

output "public_subnets" {
  description = "List of public subnet IDs"
  value       = module.vpc.public_subnets
}

output "private_subnets" {
  description = "List of private subnet IDs"
  value       = module.vpc.private_subnets
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = module.vpc.internet_gateway_id
}

#-------------EKS-----------------

output "eks_cluster_endpoint" {
  description = "EKS API endpoint for connecting to the cluster"
  value       = module.eks.eks_cluster_endpoint
}

output "eks_cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.eks_cluster_name
}

output "eks_node_role_arn" {
  description = "IAM role ARN for EKS Worker Nodes"
  value       = module.eks.eks_node_role_arn
}

#-------------JENKINS-----------------

output "jenkins_release" {
  value = module.jenkins.jenkins_release_name
}

output "jenkins_namespace" {
  value = module.jenkins.jenkins_namespace
}

#-------------RDS-----------------

output "rds_endpoint" {
  description = "RDS/Aurora connection endpoint"
  value       = module.rds.endpoint
}

output "rds_port" {
  description = "RDS/Aurora port"
  value       = module.rds.port
}

output "rds_password" {
  description = "RDS master password (generated when not provided)"
  value       = module.rds.password
  sensitive   = true
}

#-------------MONITORING-----------------

output "monitoring_namespace" {
  description = "Namespace where Prometheus & Grafana are deployed"
  value       = module.monitoring.namespace
}

output "grafana_service_name" {
  description = "Grafana Kubernetes Service name (LoadBalancer)"
  value       = module.monitoring.grafana_service_name
}
