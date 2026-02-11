variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "eu-west-1"
}

variable "state_bucket_name" {
  description = "Name of the S3 bucket for Terraform state storage (must be globally unique)"
  type        = string
  default     = "workshop-ua-terraform-state-bucket"
}

variable "dynamodb_table_name" {
  description = "Name of the DynamoDB table for Terraform state locking"
  type        = string
  default     = "terraform-state-locks"
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "ci_user_name" {
  description = "Name of the IAM user for Terraform CI/CD"
  type        = string
  default     = "terraform-ci"
}
