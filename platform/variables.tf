variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "eu-west-1"
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "workshop-eks-cluster"
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.35"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones for subnet placement"
  type        = list(string)
  default     = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (one per availability zone)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (one per availability zone)"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
}

variable "cluster_endpoint_private_access" {
  description = "Enable private API server endpoint"
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access" {
  description = "Enable public API server endpoint"
  type        = bool
  default     = true
}

variable "cluster_log_types" {
  description = "List of control plane logging types to enable"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "cluster_log_retention_days" {
  description = "Number of days to retain cluster logs in CloudWatch"
  type        = number
  default     = 7
}

variable "single_nat_gateway" {
  description = "Use a single NAT Gateway for all private subnets (cost optimization)"
  type        = bool
  default     = true
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnet internet access"
  type        = bool
  default     = true
}

variable "cluster_admin_arns" {
  description = "List of IAM principal ARNs to grant EKS cluster admin access (root user is always included)"
  type        = list(string)
  default     = []
}

variable "fargate_namespaces" {
  description = "List of Kubernetes namespaces to create Fargate profiles for"
  type        = list(string)
  default     = ["kube-system", "default"]
}

variable "projects" {
  description = "List of project names to create ECR repositories and CI/CD users for"
  type        = list(string)
  default     = []
}

# ============================================================================
# Aurora PostgreSQL Configuration
# ============================================================================

variable "enable_aurora" {
  description = "Enable Aurora PostgreSQL cluster deployment"
  type        = bool
  default     = false
}

variable "aurora_engine_version" {
  description = "Aurora PostgreSQL engine version"
  type        = string
  default     = "16.6"
}

variable "aurora_min_capacity" {
  description = "Minimum Aurora Serverless v2 capacity in ACUs (0.5 to 128)"
  type        = number
  default     = 0.5
}

variable "aurora_max_capacity" {
  description = "Maximum Aurora Serverless v2 capacity in ACUs (0.5 to 128)"
  type        = number
  default     = 4
}

variable "aurora_database_name" {
  description = "Name of the default database to create in Aurora"
  type        = string
  default     = "workshop"
}

variable "aurora_master_username" {
  description = "Master username for the Aurora cluster"
  type        = string
  default     = "workshop_admin"
}

variable "aurora_port" {
  description = "Port for the Aurora PostgreSQL cluster"
  type        = number
  default     = 5432
}

variable "aurora_backup_retention_period" {
  description = "Number of days to retain Aurora automated backups"
  type        = number
  default     = 7
}

variable "aurora_backup_schedule" {
  description = "Cron expression for AWS Backup schedule (default: daily at 02:00 UTC)"
  type        = string
  default     = "cron(0 2 * * ? *)"
}

variable "aurora_backup_delete_after_days" {
  description = "Number of days after which AWS Backup recovery points are deleted"
  type        = number
  default     = 35
}

variable "aurora_deletion_protection" {
  description = "Enable deletion protection on the Aurora cluster"
  type        = bool
  default     = true
}

variable "aurora_skip_final_snapshot" {
  description = "Skip final snapshot when destroying the Aurora cluster"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
