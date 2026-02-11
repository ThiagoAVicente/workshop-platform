# Terraform State Backend Configuration
#
# Multi-account setup: Each AWS account has its own state bucket.
# CI/CD workflows override the bucket name for each environment:
#   - Dev:  workshop-ua-dev-terraform-state
#   - Stg:  workshop-ua-stg-terraform-state
#   - Prd:  workshop-ua-prd-terraform-state
#
# For local development, update the bucket name to match your target environment
# or use: terraform init -backend-config="bucket=workshop-ua-<env>-terraform-state"

terraform {
  backend "s3" {
    bucket         = "workshop-ua-dev-terraform-state"
    key            = "platform/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "terraform-state-locks"
    encrypt        = true
  }
}
