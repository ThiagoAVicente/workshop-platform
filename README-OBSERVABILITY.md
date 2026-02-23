# Observability Stack

Self-hosted Prometheus + Grafana stack deployed on EKS Fargate, with pod log collection via Fargate's built-in Fluent Bit log router.

## Architecture

```
Pod stdout/stderr ──> Fargate Log Router (Fluent Bit) ──> CloudWatch Logs ──> Grafana
                                                                                 |
K8s state metrics ──> kube-state-metrics ──> Prometheus ─────────────────────────|
                                                                                 |
App traces (OTLP) ──> Tempo ───────────────────────────────────────────────────-/
```

| Component          | Type            | Namespace          | Purpose                                    |
|--------------------|-----------------|--------------------|--------------------------------------------|
| Prometheus         | Helm release    | `monitoring`       | Scrapes and stores Kubernetes metrics      |
| kube-state-metrics | Helm dependency | `monitoring`       | Exposes Kubernetes object metrics          |
| Tempo              | Helm release    | `monitoring`       | Distributed tracing backend (OTLP)         |
| Grafana            | Helm release    | `monitoring`       | Dashboards and data source queries         |
| Fluent Bit         | Fargate built-in| (all namespaces)   | Routes pod logs to CloudWatch Logs         |
| aws-logging        | ConfigMap       | `aws-observability`| Configures the Fargate log router          |

## Fargate Constraints

This cluster runs exclusively on Fargate, which means:

- **No DaemonSets** — node-exporter and promtail are disabled
- **No EBS volumes** — Prometheus uses ephemeral storage (emptyDir); metric history is lost on pod restart
- **Log collection** uses Fargate's built-in Fluent Bit log router instead of a DaemonSet

## Required CI Variables

The following variables **must** be set as secrets in your CI/CD pipeline:

| Variable                        | Description                     | Example            |
|---------------------------------|---------------------------------|--------------------|
| `TF_VAR_grafana_admin_password` | Grafana admin login password    | *(secure string)*  |

Set this as a **secret environment variable** in your CI system (e.g., GitHub Actions secret, GitLab CI variable). It is marked `sensitive` in Terraform and will not appear in plan output.

### Example (GitHub Actions)

```yaml
env:
  TF_VAR_grafana_admin_password: ${{ secrets.GRAFANA_ADMIN_PASSWORD }}
```

### Example (CLI for local development)

```bash
export TF_VAR_grafana_admin_password="your-secure-password"
terraform plan -var-file=environments/dev.tfvars
```

## Accessing Grafana

### Port-forward (development)

```bash
kubectl port-forward -n monitoring svc/grafana 3000:80
```

Then open http://localhost:3000 and log in with `admin` / your configured password.

### Via Ingress (production)

To expose Grafana externally, create an Ingress resource using the AWS Load Balancer Controller. Example:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: grafana
  namespace: monitoring
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
spec:
  ingressClassName: alb
  rules:
    - host: grafana.your-domain.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: grafana
                port:
                  number: 80
```

## Pre-configured Data Sources

| Name       | Type       | Access Method                          |
|------------|------------|----------------------------------------|
| Prometheus | prometheus | Cluster-internal (`prometheus-server.monitoring.svc.cluster.local:9090`) |
| CloudWatch | cloudwatch | IRSA (Grafana service account has IAM role with CloudWatch read permissions) |
| Tempo      | tempo      | Cluster-internal (`tempo.monitoring.svc.cluster.local:3100`) |

## Pre-loaded Dashboards

The following dashboards are automatically imported from grafana.com:

| Dashboard                  | Grafana ID | Description                           |
|----------------------------|------------|---------------------------------------|
| Kubernetes Cluster         | 6417       | Cluster-wide resource overview        |
| Kubernetes Pods            | 6336       | Per-pod CPU, memory, network metrics  |
| Kubernetes Namespaces      | 15758      | Namespace-level resource breakdown    |

## How Log Collection Works

1. Fargate automatically runs a Fluent Bit sidecar on every pod
2. The `aws-logging` ConfigMap in `aws-observability` namespace configures the log destination
3. All pod stdout/stderr is shipped to CloudWatch Logs group `/aws/eks/<cluster-name>/pods`
4. Grafana queries CloudWatch Logs via the CloudWatch data source (authenticated with IRSA)

Log retention is environment-specific:
- **dev**: 3 days
- **stg**: 7 days
- **prd**: 30 days

## Prometheus Metrics

Prometheus collects metrics from:
- **kube-state-metrics**: Kubernetes object states (deployments, pods, nodes, etc.)
- **Pod annotations**: Any pod with `prometheus.io/scrape: "true"` annotation will be scraped automatically

To make your application expose metrics to Prometheus, add these annotations to your pod spec:

```yaml
annotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "8080"
  prometheus.io/path: "/metrics"
```

## Spring Boot Integration

Spring Boot applications can integrate with all three observability pillars (logs, metrics, traces) using the Micrometer and OpenTelemetry ecosystem.

### Dependencies

Add these to your `pom.xml`:

```xml
<dependencies>
    <!-- Metrics: Prometheus endpoint -->
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-actuator</artifactId>
    </dependency>
    <dependency>
        <groupId>io.micrometer</groupId>
        <artifactId>micrometer-registry-prometheus</artifactId>
    </dependency>

    <!-- Traces: OpenTelemetry auto-instrumentation via Micrometer -->
    <dependency>
        <groupId>io.micrometer</groupId>
        <artifactId>micrometer-tracing-bridge-otel</artifactId>
    </dependency>
    <dependency>
        <groupId>io.opentelemetry</groupId>
        <artifactId>opentelemetry-exporter-otlp</artifactId>
    </dependency>
</dependencies>
```

Or with Gradle:

```groovy
implementation 'org.springframework.boot:spring-boot-starter-actuator'
implementation 'io.micrometer:micrometer-registry-prometheus'
implementation 'io.micrometer:micrometer-tracing-bridge-otel'
implementation 'io.opentelemetry:opentelemetry-exporter-otlp'
```

### Application Configuration

Add to `application.yml`:

```yaml
management:
  endpoints:
    web:
      exposure:
        include: health, info, prometheus, metrics
  endpoint:
    health:
      show-details: always
  metrics:
    tags:
      application: ${spring.application.name}
    distribution:
      percentiles-histogram:
        http.server.requests: true
  tracing:
    sampling:
      probability: 1.0  # Sample all traces in dev; reduce in production (e.g. 0.1)

logging:
  pattern:
    console: "%d{yyyy-MM-dd HH:mm:ss.SSS} [%thread] [traceId=%mdc{traceId} spanId=%mdc{spanId}] %-5level %logger{36} - %msg%n"
```

The log pattern embeds trace and span IDs into every log line, which allows you to correlate logs with traces in Grafana.

### Kubernetes Deployment Annotations

Add Prometheus scrape annotations to your pod template so that Prometheus automatically discovers and scrapes metrics:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-spring-app
spec:
  template:
    metadata:
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
        prometheus.io/path: "/actuator/prometheus"
    spec:
      containers:
        - name: app
          image: <ecr-repo>/my-spring-app:latest
          ports:
            - containerPort: 8080
          env:
            - name: MANAGEMENT_ENDPOINTS_WEB_EXPOSURE_INCLUDE
              value: "health,info,prometheus,metrics"
```

### Logs

No additional setup is needed for logs. Spring Boot writes to stdout by default, and Fargate's built-in Fluent Bit log router automatically ships all stdout/stderr to CloudWatch Logs. The structured log pattern above adds trace IDs to each line.

To query logs for a specific application in Grafana, use the CloudWatch data source with a Logs Insights query:

```
fields @timestamp, @message
| filter @logStream like /my-spring-app/
| sort @timestamp desc
| limit 200
```

To find logs for a specific trace:

```
fields @timestamp, @message
| filter @message like /traceId=<your-trace-id>/
| sort @timestamp desc
```

### Metrics

Once the Prometheus annotations are in place, the following metrics are automatically available in Grafana via the Prometheus data source:

| Metric | Description |
|--------|-------------|
| `http_server_requests_seconds_count` | Request count by URI, method, status |
| `http_server_requests_seconds_sum` | Total request duration |
| `http_server_requests_seconds_bucket` | Request duration histogram (for percentiles) |
| `jvm_memory_used_bytes` | JVM heap and non-heap memory usage |
| `jvm_gc_pause_seconds_count` | Garbage collection pause count |
| `jvm_threads_live_threads` | Number of live threads |
| `process_cpu_usage` | Process CPU utilization |
| `hikaricp_connections_active` | Active database connections (if using HikariCP) |
| `spring_data_repository_invocations_seconds_*` | Spring Data repository call durations |

Example PromQL queries for Grafana panels:

```promql
# Request rate by endpoint
rate(http_server_requests_seconds_count{application="my-spring-app"}[5m])

# P95 latency by endpoint
histogram_quantile(0.95, rate(http_server_requests_seconds_bucket{application="my-spring-app"}[5m]))

# JVM heap usage
jvm_memory_used_bytes{application="my-spring-app", area="heap"}

# Error rate (5xx responses)
rate(http_server_requests_seconds_count{application="my-spring-app", status=~"5.."}[5m])
```

### Traces

Grafana Tempo is deployed in the `monitoring` namespace as the distributed tracing backend. It accepts spans via OTLP on gRPC (port 4317) and HTTP (port 4318).

Configure your Spring Boot app to send traces to Tempo by setting the OTLP endpoint in your pod spec:

```yaml
env:
  - name: OTEL_EXPORTER_OTLP_ENDPOINT
    value: "http://tempo.monitoring:4317"
```

With the dependencies and `application.yml` configuration above, Spring Boot will automatically instrument HTTP requests, database calls, and other supported libraries with trace spans.

The trace IDs embedded in log lines (via the log pattern above) allow you to correlate logs with traces. In Grafana:

1. Open the **Explore** view and select the **Tempo** data source
2. Search by trace ID, service name, or duration
3. The **Node Graph** view shows the full call tree across services
4. Click a trace ID in the Pod Logs dashboard to jump directly to its trace

To verify traces are flowing:

```bash
# Port-forward Tempo and query the API
kubectl port-forward -n monitoring svc/tempo 3100:3100
curl http://localhost:3100/api/search?q=\{\}
```

## Troubleshooting

### Pods not showing logs in Grafana

1. Verify the `aws-observability` namespace exists: `kubectl get ns aws-observability`
2. Verify the ConfigMap: `kubectl get configmap aws-logging -n aws-observability -o yaml`
3. Check the CloudWatch log group exists: `aws logs describe-log-groups --log-group-name-prefix /aws/eks/`
4. Verify the Fargate pod execution role has CloudWatch Logs permissions

### Prometheus not scraping metrics

1. Check Prometheus is running: `kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus`
2. Check kube-state-metrics: `kubectl get pods -n monitoring -l app.kubernetes.io/name=kube-state-metrics`
3. Verify targets in Prometheus UI: `kubectl port-forward -n monitoring svc/prometheus-server 9090:80` then visit http://localhost:9090/targets

### Grafana cannot reach CloudWatch

1. Verify the Grafana service account has the IRSA annotation:
   ```bash
   kubectl get sa grafana-sa -n monitoring -o yaml
   ```
2. Check the IAM role trust policy allows the service account
3. Test from inside the pod:
   ```bash
   kubectl exec -n monitoring deploy/grafana -- aws sts get-caller-identity
   ```
