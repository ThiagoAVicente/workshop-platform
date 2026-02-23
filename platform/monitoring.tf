# ============================================================================
# Monitoring Stack — Fargate Profile
# ============================================================================

resource "aws_eks_fargate_profile" "monitoring" {
  cluster_name           = aws_eks_cluster.main.name
  fargate_profile_name   = "monitoring"
  pod_execution_role_arn = aws_iam_role.fargate.arn
  subnet_ids             = aws_subnet.private[*].id

  selector {
    namespace = "monitoring"
  }

  tags = {
    Name = "${var.cluster_name}-monitoring-fargate-profile"
  }
}

# ============================================================================
# Fargate Log Router — aws-observability namespace + ConfigMap
# ============================================================================
# Fargate's built-in Fluent Bit log router reads its configuration from a
# ConfigMap named "aws-logging" in the "aws-observability" namespace. This
# routes all pod stdout/stderr logs to CloudWatch Logs automatically.

resource "kubernetes_namespace" "aws_observability" {
  metadata {
    name = "aws-observability"

    labels = {
      "aws-observability"            = "enabled"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  depends_on = [aws_eks_cluster.main]
}

resource "aws_cloudwatch_log_group" "pod_logs" {
  name              = "/aws/eks/${var.cluster_name}/pods"
  retention_in_days = var.monitoring_log_retention_days

  tags = {
    Name = "${var.cluster_name}-pod-logs"
  }
}

resource "kubernetes_config_map" "aws_logging" {
  metadata {
    name      = "aws-logging"
    namespace = "aws-observability"
  }

  data = {
    "output.conf" = <<-EOT
      [OUTPUT]
          Name cloudwatch_logs
          Match *
          region ${var.aws_region}
          log_group_name /aws/eks/${var.cluster_name}/pods
          log_stream_prefix fargate-
          auto_create_group true
    EOT

    "parsers.conf" = <<-EOT
      [PARSER]
          Name cri
          Format regex
          Regex ^(?<time>[^ ]+) (?<stream>stdout|stderr) (?<logtag>[^ ]*) (?<log>.*)$
          Time_Key time
          Time_Format %Y-%m-%dT%H:%M:%S.%L%z
    EOT

    "filters.conf" = <<-EOT
      [FILTER]
          Name parser
          Match *
          Key_name log
          Parser cri
    EOT
  }

  depends_on = [kubernetes_namespace.aws_observability]
}

# ============================================================================
# Prometheus — Helm Release
# ============================================================================

resource "helm_release" "prometheus" {
  name             = "prometheus"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "prometheus"
  namespace        = "monitoring"
  create_namespace = true
  timeout          = 900

  # Server as Deployment (no StatefulSet — Fargate has no EBS support)
  set {
    name  = "server.statefulSet.enabled"
    value = "false"
  }

  set {
    name  = "server.persistentVolume.enabled"
    value = "false"
  }

  # kube-state-metrics runs as a Deployment (works on Fargate)
  set {
    name  = "kube-state-metrics.enabled"
    value = "true"
  }

  # Disable DaemonSet-based components (not supported on Fargate)
  set {
    name  = "nodeExporter.enabled"
    value = "false"
  }

  set {
    name  = "prometheus-node-exporter.enabled"
    value = "false"
  }

  # Disable components not needed for workshop
  set {
    name  = "alertmanager.enabled"
    value = "false"
  }

  set {
    name  = "prometheus-pushgateway.enabled"
    value = "false"
  }

  # Expose the service on 9090 to match the container port (avoids
  # port-translation issues on Fargate's kube-proxy)
  set {
    name  = "server.service.servicePort"
    value = "9090"
  }

  # Resource requests — Fargate uses these to size the microVM.
  # Without explicit requests, Fargate assigns the minimum (0.25 vCPU / 0.5 GB)
  # which is too small for Prometheus to start reliably.
  set {
    name  = "server.resources.requests.cpu"
    value = "2000m"
  }

  set {
    name  = "server.resources.requests.memory"
    value = "4Gi"
  }

  set {
    name  = "server.resources.limits.memory"
    value = "4Gi"
  }

  # Give Prometheus more time to start on Fargate (WAL replay can be slow)
  set {
    name  = "server.readinessProbeInitialDelaySeconds"
    value = "60"
  }

  set {
    name  = "server.livenessProbeInitialDelaySeconds"
    value = "60"
  }

  depends_on = [
    aws_eks_fargate_profile.monitoring,
    kubernetes_config_map.aws_logging,
    aws_eks_addon.coredns
  ]
}

# ============================================================================
# Tempo — Helm Release (distributed tracing backend)
# ============================================================================
# Tempo runs in monolithic mode (single binary). It accepts OTLP traces on
# gRPC (4317) and HTTP (4318). Applications send spans via OpenTelemetry and
# Grafana queries them through the Tempo data source.

resource "helm_release" "tempo" {
  name       = "tempo"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "tempo"
  namespace  = "monitoring"
  timeout    = 900

  # No persistent volume on Fargate (emptyDir)
  set {
    name  = "tempo.storage.trace.backend"
    value = "local"
  }

  set {
    name  = "persistence.enabled"
    value = "false"
  }

  # Enable OTLP receivers for trace ingestion
  set {
    name  = "tempo.receivers.otlp.protocols.grpc.endpoint"
    value = "0.0.0.0:4317"
  }

  set {
    name  = "tempo.receivers.otlp.protocols.http.endpoint"
    value = "0.0.0.0:4318"
  }

  # Enable the metrics-generator so Grafana can query /api/metrics/query_range
  set {
    name  = "tempo.metricsGenerator.enabled"
    value = "true"
  }

  set {
    name  = "tempo.metricsGenerator.remoteWriteUrl"
    value = "http://prometheus-server.monitoring.svc.cluster.local:9090/api/v1/write"
  }

  # Resource requests — Fargate uses these to size the microVM.
  # Without explicit requests, Fargate assigns the minimum (0.25 vCPU / 0.5 GB)
  # which causes the pod to crash or fail readiness checks.
  set {
    name  = "tempo.resources.requests.cpu"
    value = "2000m"
  }

  set {
    name  = "tempo.resources.requests.memory"
    value = "2Gi"
  }

  set {
    name  = "tempo.resources.limits.memory"
    value = "2Gi"
  }

  depends_on = [
    aws_eks_fargate_profile.monitoring,
    kubernetes_config_map.aws_logging,
    aws_eks_addon.coredns
  ]
}

# ============================================================================
# Grafana — IAM Role (IRSA) for CloudWatch access
# ============================================================================

resource "aws_iam_role" "grafana" {
  name = "${var.cluster_name}-grafana-role"

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
            "${local.oidc_provider_id}:aud" = "sts.amazonaws.com"
            "${local.oidc_provider_id}:sub" = "system:serviceaccount:monitoring:grafana-sa"
          }
        }
      }
    ]
  })

  tags = {
    Name    = "${var.cluster_name}-grafana-role"
    Purpose = "Grafana IRSA for CloudWatch access"
  }
}

resource "aws_iam_policy" "grafana" {
  name        = "${var.cluster_name}-grafana-policy"
  description = "IAM policy for Grafana to read CloudWatch Logs and Metrics"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:DescribeAlarmsForMetric",
          "cloudwatch:DescribeAlarmHistory",
          "cloudwatch:DescribeAlarms",
          "cloudwatch:ListMetrics",
          "cloudwatch:GetMetricData",
          "cloudwatch:GetInsightRuleReport"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:DescribeLogGroups",
          "logs:GetLogGroupFields",
          "logs:StartQuery",
          "logs:StopQuery",
          "logs:GetQueryResults",
          "logs:GetLogEvents",
          "logs:FilterLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeRegions"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "oam:ListSinks",
          "oam:ListAttachedLinks"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "grafana" {
  role       = aws_iam_role.grafana.name
  policy_arn = aws_iam_policy.grafana.arn
}

# ============================================================================
# Grafana — Helm Release
# ============================================================================

resource "helm_release" "grafana" {
  name       = "grafana"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"
  namespace  = "monitoring"
  timeout    = 900

  # Service account with IRSA for CloudWatch access
  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "grafana-sa"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.grafana.arn
  }

  # Admin credentials
  set {
    name  = "adminUser"
    value = "admin"
  }

  set_sensitive {
    name  = "adminPassword"
    value = var.grafana_admin_password
  }

  # No persistent volume on Fargate (emptyDir)
  set {
    name  = "persistence.enabled"
    value = "false"
  }

  # Data sources — configured via values block for complex nested YAML
  values = [
    yamlencode({
      datasources = {
        "datasources.yaml" = {
          apiVersion = 1
          datasources = [
            {
              name      = "Prometheus"
              type      = "prometheus"
              url       = "http://prometheus-server.monitoring.svc.cluster.local:9090"
              access    = "proxy"
              isDefault = true
            },
            {
              name   = "CloudWatch"
              type   = "cloudwatch"
              uid    = "cloudwatch"
              access = "proxy"
              jsonData = {
                authType      = "default"
                defaultRegion = var.aws_region
                logGroups = [{
                  arn  = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/eks/${var.cluster_name}/pods"
                  name = "/aws/eks/${var.cluster_name}/pods"
                }]
              }
            },
            {
              name   = "Tempo"
              type   = "tempo"
              uid    = "tempo"
              url    = "http://tempo.monitoring.svc.cluster.local:3200"
              access = "proxy"
              jsonData = {
                tracesToLogsV2 = {
                  datasourceUid = "cloudwatch"
                }
                tracesToMetrics = {
                  datasourceUid = "Prometheus"
                }
                nodeGraph = {
                  enabled = true
                }
              }
            }
          ]
        }
      }
      dashboardProviders = {
        "dashboardproviders.yaml" = {
          apiVersion = 1
          providers = [
            {
              name            = "default"
              orgId           = 1
              folder          = "Kubernetes"
              type            = "file"
              disableDeletion = false
              editable        = true
              options = {
                path = "/var/lib/grafana/dashboards/default"
              }
            },
            {
              name            = "logs"
              orgId           = 1
              folder          = "Logs"
              type            = "file"
              disableDeletion = false
              editable        = true
              options = {
                path = "/var/lib/grafana/dashboards/logs"
              }
            }
          ]
        }
      }
      dashboards = {
        default = {
          kubernetes-cluster = {
            gnetId     = 6417
            revision   = 1
            datasource = "Prometheus"
          }
          kubernetes-pods = {
            gnetId     = 6336
            revision   = 1
            datasource = "Prometheus"
          }
          kubernetes-namespaces = {
            gnetId     = 15758
            revision   = 1
            datasource = "Prometheus"
          }
        }
      }
      dashboardsConfigMaps = {
        logs = "grafana-logs-dashboard"
      }
    })
  ]

  depends_on = [
    aws_eks_fargate_profile.monitoring,
    helm_release.prometheus,
    helm_release.tempo,
    kubernetes_config_map.grafana_logs_dashboard,
    aws_eks_addon.coredns
  ]
}

# ============================================================================
# Grafana — Pod Logs Dashboard (CloudWatch Logs)
# ============================================================================

resource "kubernetes_config_map" "grafana_logs_dashboard" {
  metadata {
    name      = "grafana-logs-dashboard"
    namespace = "monitoring"
  }

  data = {
    "pod-logs.json" = jsonencode({
      title       = "Pod Logs"
      description = "CloudWatch Logs from Fargate pod log router"
      editable    = true
      time = {
        from = "now-1h"
        to   = "now"
      }
      templating = {
        list = []
      }
      panels = [
        {
          id    = 1
          title = "Log Volume"
          type  = "timeseries"
          gridPos = {
            h = 6
            w = 24
            x = 0
            y = 0
          }
          targets = [
            {
              datasource = { type = "cloudwatch", uid = "cloudwatch" }
              id         = ""
              queryMode  = "Logs"
              logGroups = [
                {
                  arn  = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/eks/${var.cluster_name}/pods"
                  name = "/aws/eks/${var.cluster_name}/pods"
                }
              ]
              expression  = "stats count(*) as logCount by bin(1m)"
              statsGroups = ["bin(1m)"]
              region      = var.aws_region
              refId       = "A"
            }
          ]
          fieldConfig = {
            defaults = {
              custom = {
                drawStyle   = "bars"
                fillOpacity = 50
              }
            }
          }
        },
        {
          id    = 2
          title = "Recent Logs"
          type  = "logs"
          gridPos = {
            h = 18
            w = 24
            x = 0
            y = 6
          }
          options = {
            showTime         = true
            showLabels       = true
            wrapLogMessage   = true
            sortOrder        = "Descending"
            enableLogDetails = true
          }
          targets = [
            {
              datasource = { type = "cloudwatch", uid = "cloudwatch" }
              id         = ""
              queryMode  = "Logs"
              logGroups = [
                {
                  arn  = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/eks/${var.cluster_name}/pods"
                  name = "/aws/eks/${var.cluster_name}/pods"
                }
              ]
              expression  = "fields @timestamp, @message, @logStream\n| sort @timestamp desc\n| limit 500"
              statsGroups = []
              region      = var.aws_region
              refId       = "A"
            }
          ]
        }
      ]
      schemaVersion = 39
    })
  }

  depends_on = [aws_eks_fargate_profile.monitoring]
}

# ============================================================================
# Grafana — Ingress (internet-facing ALB)
# ============================================================================

resource "kubernetes_ingress_v1" "grafana" {
  metadata {
    name      = "grafana"
    namespace = "monitoring"

    annotations = {
      "alb.ingress.kubernetes.io/scheme"       = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"  = "ip"
      "alb.ingress.kubernetes.io/listen-ports" = jsonencode([{ HTTP = 80 }])
    }
  }

  spec {
    ingress_class_name = "alb"

    default_backend {
      service {
        name = "grafana"
        port {
          number = 80
        }
      }
    }
  }

  depends_on = [
    helm_release.grafana,
    helm_release.aws_load_balancer_controller
  ]
}
