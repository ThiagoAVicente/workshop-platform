variable "cluster_name" {
  description = "Name prefix for the Aurora cluster and related resources"
  type        = string
}

variable "engine_version" {
  description = "Aurora PostgreSQL engine version"
  type        = string
  default     = "16.6"
}

variable "min_capacity" {
  description = "Minimum Aurora Serverless v2 capacity in ACUs (0.5 to 128)"
  type        = number
  default     = 0.5
}

variable "max_capacity" {
  description = "Maximum Aurora Serverless v2 capacity in ACUs (0.5 to 128)"
  type        = number
  default     = 4
}

variable "database_name" {
  description = "Name of the default database to create"
  type        = string
  default     = "workshop"
}

variable "master_username" {
  description = "Master username for the Aurora cluster"
  type        = string
  default     = "workshop_admin"
}

variable "vpc_id" {
  description = "ID of the VPC where Aurora will be deployed"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the Aurora DB subnet group"
  type        = list(string)
}

variable "allowed_security_group_ids" {
  description = "List of security group IDs allowed to connect to Aurora on the PostgreSQL port"
  type        = list(string)
  default     = []
}

variable "port" {
  description = "Port for the Aurora PostgreSQL cluster"
  type        = number
  default     = 5432
}

variable "backup_retention_period" {
  description = "Number of days to retain Aurora automated backups"
  type        = number
  default     = 7
}

variable "preferred_backup_window" {
  description = "Daily time range for Aurora automated backups (UTC)"
  type        = string
  default     = "03:00-04:00"
}

variable "preferred_maintenance_window" {
  description = "Weekly time range for system maintenance (UTC)"
  type        = string
  default     = "sun:05:00-sun:06:00"
}

variable "deletion_protection" {
  description = "Enable deletion protection on the Aurora cluster"
  type        = bool
  default     = true
}

variable "storage_encrypted" {
  description = "Enable encryption at rest for the Aurora cluster"
  type        = bool
  default     = true
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot when destroying the cluster"
  type        = bool
  default     = false
}

variable "backup_schedule" {
  description = "Cron expression for AWS Backup schedule (default: daily at 02:00 UTC)"
  type        = string
  default     = "cron(0 2 * * ? *)"
}

variable "backup_delete_after_days" {
  description = "Number of days after which AWS Backup recovery points are deleted"
  type        = number
  default     = 35
}

variable "environment" {
  description = "Environment name (e.g., dev, stg, prd)"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
