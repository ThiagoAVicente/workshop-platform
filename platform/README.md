# EKS Fargate Platform Infrastructure

This directory contains Terraform configuration for deploying a production-grade Amazon EKS cluster with AWS Fargate compute to the workshop platform.

## Overview

This configuration creates a complete Kubernetes platform with:
- **VPC Networking**: New VPC with 3 availability zones, public and private subnets
- **EKS Cluster**: Kubernetes cluster with Fargate-only compute (serverless pods)
- **Fargate Profiles**: Pre-configured for kube-system and default namespaces
- **IRSA Support**: IAM Roles for Service Accounts with OIDC provider
- **AWS Load Balancer Controller**: Ready-to-install with pre-configured IAM roles
- **Security**: Control plane logging, private subnets for pods, proper security groups
- **Cost Optimization**: Single NAT Gateway, Fargate pay-per-use pricing

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         VPC (10.0.0.0/16)                       │
│                                                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐        │
│  │   AZ eu-w-1a │  │   AZ eu-w-1b │  │   AZ eu-w-1c │        │
│  │              │  │              │  │              │        │
│  │  Public      │  │  Public      │  │  Public      │        │
│  │  10.0.1.0/24 │  │  10.0.2.0/24 │  │  10.0.3.0/24 │        │
│  │      ↓       │  │              │  │              │        │
│  │  [NAT GW]    │  │              │  │              │        │
│  │      ↓       │  │              │  │              │        │
│  │  Private     │  │  Private     │  │  Private     │        │
│  │ 10.0.11.0/24 │  │ 10.0.12.0/24 │  │ 10.0.13.0/24 │        │
│  │              │  │              │  │              │        │
│  │ [Fargate     │  │ [Fargate     │  │ [Fargate     │        │
│  │   Pods]      │  │   Pods]      │  │   Pods]      │        │
│  └──────────────┘  └──────────────┘  └──────────────┘        │
│                                                                 │
│  EKS Control Plane (Managed by AWS)                            │
│  ├─ Private API endpoint (cluster management)                  │
│  └─ Public API endpoint (kubectl access)                       │
└─────────────────────────────────────────────────────────────────┘
```

## Prerequisites

Before deploying this infrastructure, ensure you have:

- **AWS CLI**: Configured with appropriate credentials
- **Terraform**: Version >= 1.0
- **kubectl**: For cluster management after deployment
- **Helm**: For installing AWS Load Balancer Controller (v3.0+)
- **AWS Permissions**: Ability to create VPC, EKS, IAM, and CloudWatch resources

## Key Features

### Fargate-Only Architecture

This cluster uses **AWS Fargate exclusively** for compute:
- No EC2 node groups to manage or patch
- Pay only for vCPU and memory consumed by running pods
- Automatic scaling at the pod level
- No Cluster Autoscaler needed
- Reduced operational overhead

### Cost Optimization

- **Single NAT Gateway**: Reduces costs by ~$32/month (acceptable for dev/staging)
- **Fargate Pricing**: No idle node costs, pay per pod
- **Log Retention**: 7 days default (configurable)
- **Right-sized Subnets**: /24 provides 251 IPs per subnet for pod scheduling

### Security Best Practices

- Fargate pods run in private subnets only
- Control plane logging enabled (audit, API, authenticator, controller manager, scheduler)
- IAM roles follow principle of least privilege
- IRSA (IAM Roles for Service Accounts) for pod-level AWS permissions
- Encryption at rest and in transit (EKS defaults)
- Public access to control plane can be restricted by CIDR if needed

## Variables

| Variable | Description | Type | Default |
|----------|-------------|------|---------|
| `aws_region` | AWS region for resources | string | `eu-west-1` |
| `environment` | Environment name | string | `dev` |
| `cluster_name` | EKS cluster name | string | `workshop-eks-cluster` |
| `kubernetes_version` | Kubernetes version | string | `1.31` |
| `vpc_cidr` | VPC CIDR block | string | `10.0.0.0/16` |
| `availability_zones` | List of AZs | list(string) | `["eu-west-1a", "eu-west-1b", "eu-west-1c"]` |
| `public_subnet_cidrs` | Public subnet CIDRs | list(string) | `["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]` |
| `private_subnet_cidrs` | Private subnet CIDRs | list(string) | `["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]` |
| `cluster_endpoint_private_access` | Enable private endpoint | bool | `true` |
| `cluster_endpoint_public_access` | Enable public endpoint | bool | `true` |
| `cluster_log_types` | Control plane logs | list(string) | `["api", "audit", "authenticator", "controllerManager", "scheduler"]` |
| `cluster_log_retention_days` | Log retention days | number | `7` |
| `single_nat_gateway` | Use single NAT gateway | bool | `true` |
| `enable_nat_gateway` | Enable NAT gateway | bool | `true` |
| `fargate_namespaces` | Namespaces for Fargate profiles | list(string) | `["kube-system", "default"]` |
| `tags` | Additional resource tags | map(string) | `{}` |

## Deployment

### 1. Configure Variables

Create a `terraform.tfvars` file:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and customize values as needed.

### 2. Initialize Terraform

```bash
terraform init
```

### 3. Review the Plan

```bash
terraform plan
```

Expected resources: ~40-50 resources including VPC, subnets, EKS cluster, Fargate profiles, IAM roles, etc.

### 4. Apply the Configuration

```bash
terraform apply
```

⏱️ **Expected Duration**: 15-20 minutes (EKS cluster creation takes 10-15 minutes)

### 5. Configure kubectl

After successful deployment, configure kubectl:

```bash
aws eks update-kubeconfig --region eu-west-1 --name workshop-eks-cluster
```

### 6. Verify Cluster Access

```bash
# Check cluster info
kubectl cluster-info

# View nodes (Fargate nodes appear when pods are scheduled)
kubectl get nodes

# Check system pods
kubectl get pods -n kube-system
```

## Post-Deployment Steps

### Install AWS Load Balancer Controller

The cluster is pre-configured with IAM roles for the AWS Load Balancer Controller. Install it using Helm:

```bash
# Add the EKS Helm repository
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Install the controller (use the Helm install command from outputs)
terraform output -raw lb_controller_helm_install_command | bash
```

Verify the installation:

```bash
kubectl get deployment -n kube-system aws-load-balancer-controller
kubectl logs -n kube-system deployment/aws-load-balancer-controller
```

### Test Pod Scheduling

Deploy a test pod to verify Fargate scheduling:

```bash
kubectl run nginx-test --image=nginx --namespace=default
kubectl get pod nginx-test -o wide

# Check that it's running on Fargate
kubectl describe pod nginx-test | grep "fargate-"
```

### Create a Sample Ingress

Test the Load Balancer Controller:

```yaml
# sample-ingress.yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
  namespace: default
spec:
  selector:
    app: nginx
  ports:
    - port: 80
      targetPort: 80
  type: NodePort
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx-ingress
  namespace: default
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
spec:
  ingressClassName: alb
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: nginx-service
                port:
                  number: 80
```

Apply and verify:

```bash
kubectl apply -f sample-ingress.yaml
kubectl get ingress nginx-ingress
```

## Verification Checklist

After deployment, verify:

- [ ] Cluster is active: `kubectl cluster-info`
- [ ] CoreDNS pods are running on Fargate: `kubectl get pods -n kube-system -l k8s-app=kube-dns -o wide`
- [ ] Fargate profiles exist: `aws eks list-fargate-profiles --cluster-name workshop-eks-cluster --region eu-west-1`
- [ ] OIDC provider is configured: Check IAM console or `aws iam list-open-id-connect-providers`
- [ ] Test pod can be scheduled: `kubectl run test-pod --image=nginx --namespace=default`
- [ ] AWS Load Balancer Controller is installed: `kubectl get deployment -n kube-system aws-load-balancer-controller`

## Important Notes

### Fargate-Specific Considerations

1. **CoreDNS Configuration**: CoreDNS is automatically configured for Fargate using the `computeType` configuration in the addon.

2. **No EBS Support**: Fargate uses ephemeral storage only. For persistent storage, consider:
   - Amazon EFS (requires EFS CSI driver)
   - External storage services (S3, RDS, etc.)

3. **Pod Scheduling**: Each pod gets its own dedicated Fargate compute. Pods are scheduled only in private subnets.

4. **ENI Limits**: Each pod gets its own ENI. Monitor subnet IP availability.

5. **No Cluster Autoscaler**: Not needed with Fargate - scaling happens at pod level automatically.

### Cost Considerations

**Monthly Cost Estimate** (approximate, varies by usage):
- NAT Gateway: $32/month (single gateway)
- Data transfer: $0.045/GB out to internet
- Fargate compute: $0.04048/vCPU-hour + $0.004445/GB-hour
- EKS cluster: $73/month (control plane)
- CloudWatch logs: Minimal ($0.50/GB ingested, 7-day retention)

**Example**: A cluster running 10 pods (0.25 vCPU, 0.5 GB each) 24/7:
- EKS: $73
- NAT: $32
- Fargate: ~$50-60
- **Total: ~$155-165/month** (excluding data transfer)

### Production Recommendations

For production workloads, consider:

1. **Multiple NAT Gateways**: Set `single_nat_gateway = false` for high availability
2. **Restrict Public Access**: Configure `allowed_cidr_blocks` for cluster endpoint
3. **Enable Container Insights**: Add CloudWatch Container Insights for monitoring
4. **Implement Network Policies**: Use Calico or other CNI for pod-to-pod security
5. **Increase Log Retention**: Set `cluster_log_retention_days` to 30+ for compliance
6. **Add EFS for Persistent Storage**: Install EFS CSI driver if stateful workloads are needed
7. **Implement Pod Security Standards**: Enforce restricted policy with admission controllers

## Troubleshooting

### CoreDNS Pods Not Running

**Symptom**: CoreDNS pods are pending or not scheduled.

**Solution**: The configuration automatically sets `computeType = "Fargate"` for CoreDNS. If issues persist:
```bash
kubectl get pods -n kube-system -l k8s-app=kube-dns -o wide
kubectl describe pods -n kube-system -l k8s-app=kube-dns
```

### IRSA Trust Relationship Issues

**Symptom**: Pods can't assume IAM roles.

**Solution**: Verify OIDC provider configuration:
```bash
aws iam list-open-id-connect-providers
kubectl describe serviceaccount -n kube-system aws-load-balancer-controller
```

### Pods Can't Pull Images

**Symptom**: ImagePullBackOff errors.

**Solution**: Ensure private subnets have NAT Gateway access:
```bash
# Check route tables
aws ec2 describe-route-tables --filters "Name=tag:Name,Values=*private*"

# Verify NAT gateway is active
aws ec2 describe-nat-gateways
```

### Network Connectivity Issues

**Symptom**: Pods can't reach external services.

**Solution**:
1. Verify NAT Gateway is running and has elastic IP
2. Check private subnet route table has route to NAT Gateway
3. Verify security group rules allow outbound traffic

## Cleanup

To destroy all resources:

```bash
# Delete any Load Balancers created by ingresses first
kubectl delete ingress --all --all-namespaces

# Wait for ALBs to be deleted (check AWS console)
# Then destroy Terraform resources
terraform destroy
```

**⚠️ Warning**: This will permanently delete:
- EKS cluster and all workloads
- VPC and networking components
- IAM roles and policies
- CloudWatch logs

Ensure you have backups of any important data before destroying.

## Outputs

After deployment, Terraform provides helpful outputs:

```bash
# Get cluster endpoint
terraform output cluster_endpoint

# Get kubectl config command
terraform output kubectl_config_command

# Get Load Balancer Controller Helm install command
terraform output lb_controller_helm_install_command

# Get Load Balancer Controller IAM role ARN
terraform output lb_controller_role_arn

# Get all outputs
terraform output
```

## Additional Resources

- [Amazon EKS User Guide](https://docs.aws.amazon.com/eks/latest/userguide/)
- [AWS Fargate on EKS](https://docs.aws.amazon.com/eks/latest/userguide/fargate.html)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)

## Support

For issues or questions:
- Check the troubleshooting section above
- Review AWS EKS documentation
- Check Terraform AWS provider documentation
- Review CloudWatch logs for cluster issues
