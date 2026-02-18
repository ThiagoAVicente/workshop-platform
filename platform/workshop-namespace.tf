# ============================================================================
# Workshop Namespace
# ============================================================================

resource "kubernetes_namespace" "workshop" {
  metadata {
    name = "workshop"

    labels = {
      name        = "workshop"
      environment = var.environment
      managed-by  = "terraform"
    }
  }

  depends_on = [
    aws_eks_fargate_profile.additional
  ]
}

# ============================================================================
# Kubernetes RBAC - Deployer Role
# ============================================================================

resource "kubernetes_role" "workshop_deployer" {
  metadata {
    name      = "workshop-deployer"
    namespace = kubernetes_namespace.workshop.metadata[0].name
  }

  # Workload management
  rule {
    api_groups = ["apps"]
    resources  = ["deployments", "replicasets", "statefulsets", "daemonsets"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  # Core resources
  rule {
    api_groups = [""]
    resources  = ["pods", "services", "configmaps", "secrets", "serviceaccounts", "persistentvolumeclaims"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  # Pod logs and exec for debugging
  rule {
    api_groups = [""]
    resources  = ["pods/log", "pods/exec", "pods/portforward"]
    verbs      = ["get", "list", "create"]
  }

  # Ingress and networking
  rule {
    api_groups = ["networking.k8s.io"]
    resources  = ["ingresses"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  # Jobs and CronJobs
  rule {
    api_groups = ["batch"]
    resources  = ["jobs", "cronjobs"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  # Autoscaling
  rule {
    api_groups = ["autoscaling"]
    resources  = ["horizontalpodautoscalers"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }
}

# Bind the role to the workshop-deployers Kubernetes group (used by IAM mapping)
resource "kubernetes_role_binding" "workshop_deployer_group" {
  metadata {
    name      = "workshop-deployer-group-binding"
    namespace = kubernetes_namespace.workshop.metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.workshop_deployer.metadata[0].name
  }

  subject {
    kind      = "Group"
    name      = "workshop-deployers"
    api_group = "rbac.authorization.k8s.io"
  }
}

# ============================================================================
# Kubernetes ServiceAccount - Workshop Deployer
# ============================================================================

resource "kubernetes_service_account" "workshop_deployer" {
  metadata {
    name      = "workshop-deployer"
    namespace = kubernetes_namespace.workshop.metadata[0].name

    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.workshop_deployer.arn
    }
  }
}

# Bind the role to the ServiceAccount
resource "kubernetes_role_binding" "workshop_deployer_sa" {
  metadata {
    name      = "workshop-deployer-sa-binding"
    namespace = kubernetes_namespace.workshop.metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.workshop_deployer.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.workshop_deployer.metadata[0].name
    namespace = kubernetes_namespace.workshop.metadata[0].name
  }
}

# ============================================================================
# IAM Role - Workshop Deployer (for external access via EKS access entry)
# ============================================================================

resource "aws_iam_role" "workshop_deployer" {
  name = "${var.cluster_name}-workshop-deployer"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.cluster.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${local.oidc_provider_id}:sub" = "system:serviceaccount:workshop:workshop-deployer"
            "${local.oidc_provider_id}:aud" = "sts.amazonaws.com"
          }
        }
      },
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name        = "${var.cluster_name}-workshop-deployer"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Purpose     = "Workshop namespace deployer"
    }
  )
}

# ============================================================================
# EKS Access Entry - Maps IAM role to Kubernetes group
# ============================================================================

resource "aws_eks_access_entry" "workshop_deployer" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = aws_iam_role.workshop_deployer.arn
  type          = "STANDARD"

  kubernetes_groups = ["workshop-deployers"]

  tags = merge(
    var.tags,
    {
      Name        = "${var.cluster_name}-workshop-deployer-access"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  )
}
