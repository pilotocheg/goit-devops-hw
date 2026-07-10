locals {
  # Engine that is actually in use depends on the mode
  active_engine = var.use_aurora ? var.engine_cluster : var.engine

  # Derive the port from the engine unless one is explicitly provided
  default_port = length(regexall("mysql|mariadb", local.active_engine)) > 0 ? 3306 : 5432
  db_port      = coalesce(var.db_port, local.default_port)

  # Use the provided password if any, otherwise fall back to the generated one
  master_password = (var.password != null && var.password != "") ? var.password : random_password.rds.result
}

# Auto-generated master password (used when var.password is not set).
# override_special avoids characters RDS rejects (/, @, ", space).
resource "random_password" "rds" {
  length           = 20
  special          = true
  override_special = "!#$%^&*()-_=+[]{}"
}

# Subnet group (used by both RDS and Aurora)
resource "aws_db_subnet_group" "default" {
  name       = "${var.name}-subnet-group"
  subnet_ids = var.publicly_accessible ? var.subnet_public_ids : var.subnet_private_ids
  tags       = var.tags
}

# Security group (used by both RDS and Aurora)
resource "aws_security_group" "rds" {
  name        = "${var.name}-sg"
  description = "Security group for ${var.name}"
  vpc_id      = var.vpc_id

  ingress {
    description = "DB access"
    from_port   = local.db_port
    to_port     = local.db_port
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}
