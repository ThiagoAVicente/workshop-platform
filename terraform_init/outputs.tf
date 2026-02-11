output "state_bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.id
}

output "state_bucket_arn" {
  description = "ARN of the S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.arn
}

output "state_bucket_region" {
  description = "Region of the S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.region
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table for state locking"
  value       = aws_dynamodb_table.terraform_locks.name
}

output "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table for state locking"
  value       = aws_dynamodb_table.terraform_locks.arn
}

output "backend_config" {
  description = "Backend configuration block to use in other Terraform projects"
  value = <<-EOT
    terraform {
      backend "s3" {
        bucket         = "${aws_s3_bucket.terraform_state.id}"
        key            = "terraform.tfstate"
        region         = "${aws_s3_bucket.terraform_state.region}"
        dynamodb_table = "${aws_dynamodb_table.terraform_locks.name}"
        encrypt        = true
      }
    }
  EOT
}

output "ci_user_name" {
  description = "Name of the IAM user for Terraform CI/CD"
  value       = aws_iam_user.terraform_ci.name
}

output "ci_user_arn" {
  description = "ARN of the IAM user for Terraform CI/CD"
  value       = aws_iam_user.terraform_ci.arn
}

output "ci_access_key_id" {
  description = "Access Key ID for the CI/CD user (sensitive - store securely)"
  value       = aws_iam_access_key.terraform_ci.id
  sensitive   = true
}

output "ci_secret_access_key" {
  description = "Secret Access Key for the CI/CD user (sensitive - store securely in your CI system)"
  value       = aws_iam_access_key.terraform_ci.secret
  sensitive   = true
}
