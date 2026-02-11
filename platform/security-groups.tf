# ============================================================================
# EKS Cluster Security Group
# ============================================================================

resource "aws_security_group" "cluster" {
  name_prefix = "${var.cluster_name}-cluster-sg"
  description = "Security group for EKS cluster"
  vpc_id      = aws_vpc.main.id

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
      Name        = "${var.cluster_name}-cluster-sg"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  )
}

resource "aws_security_group_rule" "cluster_ingress_workstation_https" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow workstation to communicate with cluster API"
  security_group_id = aws_security_group.cluster.id
}
