# Aurora PostgreSQL Cluster
module "aurora" {
  source = "./modules/aurora"

  cluster_name               = var.cluster_name
  engine_version             = var.aurora_engine_version
  min_capacity               = var.aurora_min_capacity
  max_capacity               = var.aurora_max_capacity
  database_name              = var.aurora_database_name
  master_username            = var.aurora_master_username
  vpc_id                     = aws_vpc.main.id
  subnet_ids                 = aws_subnet.private[*].id
  allowed_security_group_ids = [aws_security_group.cluster.id]
  port                       = var.aurora_port
  backup_retention_period    = var.aurora_backup_retention_period
  backup_schedule            = var.aurora_backup_schedule
  backup_delete_after_days   = var.aurora_backup_delete_after_days
  deletion_protection        = var.aurora_deletion_protection
  skip_final_snapshot        = var.aurora_skip_final_snapshot
  environment                = var.environment
  tags                       = var.tags
}
