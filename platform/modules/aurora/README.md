# Aurora PostgreSQL Module

Creates an Amazon Aurora PostgreSQL cluster with a writer instance, a hot standby reader, and an AWS Backup plan with configurable schedule.

## Architecture

- **Writer instance**: Primary instance handling all read/write traffic
- **Reader instance**: Hot standby with `promotion_tier = 1` for automatic failover
- **AWS Backup**: Configurable backup schedule (default: daily) with lifecycle management

## Backup Strategy

The module implements two layers of backup:

| Layer | Mechanism | Default Schedule | Retention |
|-------|-----------|-----------------|-----------|
| Aurora built-in | Continuous automated backups | Daily (03:00-04:00 UTC) | `backup_retention_period` (default: 7 days) |
| AWS Backup | Scheduled snapshots to vault | `backup_schedule` (default: daily at 02:00 UTC) | `backup_delete_after_days` (default: 35 days) |

Aurora's built-in backups are always daily. AWS Backup adds flexibility for custom frequencies (hourly, weekly, etc.) via cron expressions.

## Usage

```hcl
module "aurora" {
  source = "./modules/aurora"

  cluster_name               = "workshop-eks-dev"
  vpc_id                     = aws_vpc.main.id
  subnet_ids                 = aws_subnet.private[*].id
  allowed_security_group_ids = [aws_security_group.cluster.id]
  environment                = "dev"

  tags = {
    Environment = "dev"
    Project     = "Workshop Platform"
  }
}
```

## Resources Created

| Resource | Count | Purpose |
|----------|-------|---------|
| `aws_db_subnet_group` | 1 | Places Aurora in private subnets |
| `aws_security_group` | 1 | Network access control |
| `aws_security_group_rule` | N | Ingress rule per allowed security group |
| `aws_rds_cluster` | 1 | Aurora PostgreSQL cluster |
| `aws_rds_cluster_instance` (writer) | 1 | Primary instance |
| `aws_rds_cluster_instance` (reader) | 1 | Hot standby instance |
| `aws_iam_role` | 1 | IAM role for AWS Backup |
| `aws_iam_role_policy_attachment` | 2 | Backup and restore policies |
| `aws_backup_vault` | 1 | Dedicated backup vault |
| `aws_backup_plan` | 1 | Backup schedule and lifecycle |
| `aws_backup_selection` | 1 | Targets the Aurora cluster |

## Variables

| Name | Type | Default | Required | Description |
|------|------|---------|----------|-------------|
| `cluster_name` | `string` | n/a | yes | Name prefix for all resources |
| `engine_version` | `string` | `"16.6"` | no | Aurora PostgreSQL engine version |
| `instance_class` | `string` | `"db.r6g.large"` | no | Instance class for cluster instances |
| `database_name` | `string` | `"workshop"` | no | Default database name |
| `master_username` | `string` | `"workshop_admin"` | no | Master username |
| `vpc_id` | `string` | n/a | yes | VPC ID for security group |
| `subnet_ids` | `list(string)` | n/a | yes | Subnet IDs for DB subnet group |
| `allowed_security_group_ids` | `list(string)` | `[]` | no | Security groups allowed to connect |
| `port` | `number` | `5432` | no | PostgreSQL port |
| `backup_retention_period` | `number` | `7` | no | Aurora built-in backup retention (days) |
| `preferred_backup_window` | `string` | `"03:00-04:00"` | no | Aurora backup window (UTC) |
| `preferred_maintenance_window` | `string` | `"sun:05:00-sun:06:00"` | no | Maintenance window (UTC) |
| `deletion_protection` | `bool` | `true` | no | Prevent accidental deletion |
| `storage_encrypted` | `bool` | `true` | no | Encrypt data at rest |
| `skip_final_snapshot` | `bool` | `false` | no | Skip snapshot on destroy |
| `backup_schedule` | `string` | `"cron(0 2 * * ? *)"` | no | AWS Backup cron schedule |
| `backup_delete_after_days` | `number` | `35` | no | AWS Backup retention (days) |
| `environment` | `string` | n/a | yes | Environment name |
| `tags` | `map(string)` | `{}` | no | Tags for all resources |

## Outputs

| Name | Description |
|------|-------------|
| `cluster_endpoint` | Writer endpoint for the Aurora cluster |
| `reader_endpoint` | Reader endpoint for the Aurora cluster |
| `cluster_arn` | ARN of the Aurora cluster |
| `cluster_id` | Identifier of the Aurora cluster |
| `port` | Port the cluster is listening on |
| `database_name` | Name of the default database |
| `security_group_id` | ID of the Aurora security group |
| `master_user_secret_arn` | ARN of the Secrets Manager secret with the master password |
| `backup_vault_arn` | ARN of the AWS Backup vault |

## Password Management

The master password is **automatically generated** by RDS and stored in AWS Secrets Manager (`manage_master_user_password = true`). No manual password input is needed.

The secret ARN is available via the `master_user_secret_arn` output. Services running in EKS can retrieve the credentials using:

- **AWS Secrets Manager CSI Driver** — mounts the secret as a volume in the pod
- **Application-level SDK calls** — read from Secrets Manager using IRSA credentials

The secret JSON contains `username` and `password` fields.

### Example: Retrieving the secret via AWS CLI

```bash
aws secretsmanager get-secret-value \
  --secret-id $(terraform output -raw aurora_master_user_secret_arn) \
  --query SecretString --output text
```
