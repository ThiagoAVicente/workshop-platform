# ============================================================================
# DB Subnet Group
# ============================================================================

resource "aws_db_subnet_group" "this" {
  name        = "${var.cluster_name}-aurora-subnet-group"
  description = "Subnet group for Aurora cluster ${var.cluster_name}"
  subnet_ids  = var.subnet_ids

  tags = merge(
    var.tags,
    {
      Name        = "${var.cluster_name}-aurora-subnet-group"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  )
}

# ============================================================================
# Security Group
# ============================================================================

resource "aws_security_group" "aurora" {
  name_prefix = "${var.cluster_name}-aurora-sg"
  description = "Security group for Aurora PostgreSQL cluster"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.cluster_name}-aurora-sg"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "aurora_ingress" {
  count = length(var.allowed_security_group_ids)

  type                     = "ingress"
  from_port                = var.port
  to_port                  = var.port
  protocol                 = "tcp"
  description              = "Allow PostgreSQL access from allowed security group"
  security_group_id        = aws_security_group.aurora.id
  source_security_group_id = var.allowed_security_group_ids[count.index]
}

# ============================================================================
# Aurora PostgreSQL Cluster
# ============================================================================

resource "aws_rds_cluster" "this" {
  cluster_identifier          = "${var.cluster_name}-aurora-cluster"
  engine                      = "aurora-postgresql"
  engine_version              = var.engine_version
  database_name               = var.database_name
  master_username             = var.master_username
  manage_master_user_password = true
  port                        = var.port

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.aurora.id]

  backup_retention_period      = var.backup_retention_period
  preferred_backup_window      = var.preferred_backup_window
  preferred_maintenance_window = var.preferred_maintenance_window

  storage_encrypted = var.storage_encrypted

  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.cluster_name}-aurora-final-snapshot"

  tags = merge(
    var.tags,
    {
      Name        = "${var.cluster_name}-aurora-cluster"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  )
}

# ============================================================================
# Aurora Cluster Instances
# ============================================================================

# Primary writer instance
resource "aws_rds_cluster_instance" "writer" {
  identifier         = "${var.cluster_name}-aurora-writer"
  cluster_identifier = aws_rds_cluster.this.id
  instance_class     = var.instance_class
  engine             = aws_rds_cluster.this.engine
  engine_version     = aws_rds_cluster.this.engine_version

  db_subnet_group_name = aws_db_subnet_group.this.name

  tags = merge(
    var.tags,
    {
      Name        = "${var.cluster_name}-aurora-writer"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Role        = "writer"
    }
  )
}

# Hot standby reader instance
resource "aws_rds_cluster_instance" "reader" {
  identifier         = "${var.cluster_name}-aurora-reader"
  cluster_identifier = aws_rds_cluster.this.id
  instance_class     = var.instance_class
  engine             = aws_rds_cluster.this.engine
  engine_version     = aws_rds_cluster.this.engine_version

  db_subnet_group_name = aws_db_subnet_group.this.name

  promotion_tier = 1

  tags = merge(
    var.tags,
    {
      Name        = "${var.cluster_name}-aurora-reader"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Role        = "reader"
    }
  )

  depends_on = [aws_rds_cluster_instance.writer]
}

# ============================================================================
# AWS Backup - IAM Role
# ============================================================================

resource "aws_iam_role" "backup" {
  name = "${var.cluster_name}-aurora-backup-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "backup.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name        = "${var.cluster_name}-aurora-backup-role"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  )
}

resource "aws_iam_role_policy_attachment" "backup" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

resource "aws_iam_role_policy_attachment" "backup_restore" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
}

# ============================================================================
# AWS Backup - Vault, Plan, and Selection
# ============================================================================

resource "aws_backup_vault" "aurora" {
  name = "${var.cluster_name}-aurora-backup-vault"

  tags = merge(
    var.tags,
    {
      Name        = "${var.cluster_name}-aurora-backup-vault"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  )
}

resource "aws_backup_plan" "aurora" {
  name = "${var.cluster_name}-aurora-backup-plan"

  rule {
    rule_name         = "${var.cluster_name}-aurora-backup-rule"
    target_vault_name = aws_backup_vault.aurora.name
    schedule          = var.backup_schedule

    lifecycle {
      delete_after = var.backup_delete_after_days
    }
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.cluster_name}-aurora-backup-plan"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  )
}

resource "aws_backup_selection" "aurora" {
  name         = "${var.cluster_name}-aurora-backup-selection"
  plan_id      = aws_backup_plan.aurora.id
  iam_role_arn = aws_iam_role.backup.arn

  resources = [
    aws_rds_cluster.this.arn
  ]
}
