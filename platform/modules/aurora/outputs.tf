output "cluster_endpoint" {
  description = "Writer endpoint for the Aurora cluster"
  value       = aws_rds_cluster.this.endpoint
}

output "reader_endpoint" {
  description = "Reader endpoint for the Aurora cluster"
  value       = aws_rds_cluster.this.reader_endpoint
}

output "cluster_arn" {
  description = "ARN of the Aurora cluster"
  value       = aws_rds_cluster.this.arn
}

output "cluster_id" {
  description = "Identifier of the Aurora cluster"
  value       = aws_rds_cluster.this.id
}

output "port" {
  description = "Port the Aurora cluster is listening on"
  value       = aws_rds_cluster.this.port
}

output "database_name" {
  description = "Name of the default database"
  value       = aws_rds_cluster.this.database_name
}

output "security_group_id" {
  description = "ID of the Aurora security group"
  value       = aws_security_group.aurora.id
}

output "master_user_secret_arn" {
  description = "ARN of the Secrets Manager secret containing the master user password"
  value       = aws_rds_cluster.this.master_user_secret[0].secret_arn
}

output "backup_vault_arn" {
  description = "ARN of the AWS Backup vault for Aurora"
  value       = aws_backup_vault.aurora.arn
}
