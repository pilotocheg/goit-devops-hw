# Aurora Cluster
resource "aws_rds_cluster" "aurora" {
  count                           = var.use_aurora ? 1 : 0
  cluster_identifier              = "${var.name}-cluster"
  engine                          = var.engine_cluster
  engine_version                  = var.engine_version_cluster
  master_username                 = var.username
  master_password                 = local.master_password
  database_name                   = var.db_name
  port                            = local.db_port
  db_subnet_group_name            = aws_db_subnet_group.default.name
  vpc_security_group_ids          = [aws_security_group.rds.id]
  backup_retention_period         = var.backup_retention_period
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.aurora[0].name

  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.name}-final-snapshot"

  tags = var.tags
}

# Writer instance
resource "aws_rds_cluster_instance" "aurora_writer" {
  count                = var.use_aurora ? 1 : 0
  identifier           = "${var.name}-writer"
  cluster_identifier   = aws_rds_cluster.aurora[0].id
  instance_class       = var.instance_class
  engine               = var.engine_cluster
  db_subnet_group_name = aws_db_subnet_group.default.name
  publicly_accessible  = var.publicly_accessible

  tags = var.tags
}

# Reader replicas
resource "aws_rds_cluster_instance" "aurora_readers" {
  count                = var.use_aurora ? var.aurora_replica_count : 0
  identifier           = "${var.name}-reader-${count.index}"
  cluster_identifier   = aws_rds_cluster.aurora[0].id
  instance_class       = var.instance_class
  engine               = var.engine_cluster
  db_subnet_group_name = aws_db_subnet_group.default.name
  publicly_accessible  = var.publicly_accessible

  tags = var.tags
}

# Aurora parameter group
resource "aws_rds_cluster_parameter_group" "aurora" {
  count       = var.use_aurora ? 1 : 0
  name        = "${var.name}-aurora-params"
  family      = var.parameter_group_family_aurora
  description = "Aurora parameter group for ${var.name}"

  dynamic "parameter" {
    for_each = var.parameters
    content {
      name         = parameter.key
      value        = parameter.value
      apply_method = "pending-reboot"
    }
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = var.tags
}
