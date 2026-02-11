# Terraform State Backend Configuration
#
# IMPORTANT: This is the default backend configuration for local development.
# The CI/CD workflows override the "key" parameter for each environment:
#   - Dev:  platform/dev/terraform.tfstate
#   - Stg:  platform/stg/terraform.tfstate
#   - Prd:  platform/prd/terraform.tfstate
#
# Each AWS account should have its own state bucket and DynamoDB table.
# The state bucket is always in the same account as the infrastructure it manages.
#
# To bootstrap a new account:
#   1. Deploy terraform_init in the target AWS account
#   2. Update this bucket name to match the account's state bucket
#   3. Run: terraform init -backend-config="key=platform/<env>/terraform.tfstate"

terraform {
  backend "s3" {
    bucket         = "workshop-ua-terraform-state-bucket"
    key            = "terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "terraform-state-locks"
    encrypt        = true
  }
}
