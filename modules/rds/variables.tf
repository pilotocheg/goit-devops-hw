variable "name" {
  description = "Base name for the instance/cluster and all supporting resources"
  type        = string
}

variable "use_aurora" {
  description = "true -> Aurora Cluster, false -> single RDS instance"
  type        = bool
  default     = false
}

# --- Standard RDS engine ---
variable "engine" {
  description = "Engine for the standard RDS instance (postgres, mysql, mariadb, ...)"
  type        = string
  default     = "postgres"
}

variable "engine_version" {
  description = "Engine version for the standard RDS instance"
  type        = string
  default     = "17.5"
}

variable "parameter_group_family_rds" {
  description = "Parameter group family for the standard RDS instance (e.g. postgres17, mysql8.0)"
  type        = string
  default     = "postgres17"
}

# --- Aurora engine ---
variable "engine_cluster" {
  description = "Engine for the Aurora cluster (aurora-postgresql, aurora-mysql)"
  type        = string
  default     = "aurora-postgresql"
}

variable "engine_version_cluster" {
  description = "Engine version for the Aurora cluster"
  type        = string
  default     = "15.3"
}

variable "parameter_group_family_aurora" {
  description = "Parameter group family for the Aurora cluster (e.g. aurora-postgresql15)"
  type        = string
  default     = "aurora-postgresql15"
}

variable "aurora_replica_count" {
  description = "Number of Aurora reader replicas (writer is always created on top of this)"
  type        = number
  default     = 1
}

# --- Common ---
variable "instance_class" {
  description = "Instance class. Use db.t3.micro for the AWS Free Tier (standard RDS only)"
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Allocated storage in GB (standard RDS only; Free Tier allows up to 20)"
  type        = number
  default     = 20
}

variable "db_name" {
  description = "Name of the initial database created inside the instance/cluster"
  type        = string
}

variable "username" {
  description = "Master username"
  type        = string
}

variable "password" {
  description = "Master password. Leave null/empty to auto-generate one (recommended). Prefer TF_VAR_rds_password over hardcoding."
  type        = string
  default     = null
  sensitive   = true
}

variable "vpc_id" {
  description = "VPC in which the security group is created"
  type        = string
}

variable "subnet_private_ids" {
  description = "Private subnet IDs (used for the subnet group when not publicly accessible)"
  type        = list(string)
}

variable "subnet_public_ids" {
  description = "Public subnet IDs (used for the subnet group when publicly accessible)"
  type        = list(string)
}

variable "publicly_accessible" {
  description = "Whether the DB gets a public endpoint. Keep false unless you really need it"
  type        = bool
  default     = false
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to reach the DB port. Restrict this in production"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "db_port" {
  description = "DB port. Leave null to derive from the engine (5432 for postgres, 3306 for mysql/mariadb)"
  type        = number
  default     = null
}

variable "multi_az" {
  description = "Multi-AZ deployment (standard RDS). NOT Free Tier eligible — keep false for Free Tier"
  type        = bool
  default     = false
}

variable "backup_retention_period" {
  description = "Number of days to retain automated backups"
  type        = number
  default     = 7
}

variable "skip_final_snapshot" {
  description = "Skip the final snapshot on destroy. true is convenient for demos/dev"
  type        = bool
  default     = true
}

variable "parameters" {
  description = "Map of DB parameters applied to the parameter group"
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default     = {}
}
