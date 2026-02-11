# ============================================================================
# Fargate Profiles
# ============================================================================

resource "aws_eks_fargate_profile" "kube_system" {
  cluster_name           = aws_eks_cluster.main.name
  fargate_profile_name   = "kube-system"
  pod_execution_role_arn = aws_iam_role.fargate.arn
  subnet_ids             = aws_subnet.private[*].id

  selector {
    namespace = "kube-system"
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.cluster_name}-kube-system-fargate-profile"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  )
}

resource "aws_eks_fargate_profile" "default" {
  cluster_name           = aws_eks_cluster.main.name
  fargate_profile_name   = "default"
  pod_execution_role_arn = aws_iam_role.fargate.arn
  subnet_ids             = aws_subnet.private[*].id

  selector {
    namespace = "default"
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.cluster_name}-default-fargate-profile"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  )
}

resource "aws_eks_fargate_profile" "additional" {
  for_each = toset([for ns in var.fargate_namespaces : ns if ns != "kube-system" && ns != "default"])

  cluster_name           = aws_eks_cluster.main.name
  fargate_profile_name   = each.value
  pod_execution_role_arn = aws_iam_role.fargate.arn
  subnet_ids             = aws_subnet.private[*].id

  selector {
    namespace = each.value
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.cluster_name}-${each.value}-fargate-profile"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  )
}
