# Terraform State Management Bootstrap

This directory contains the Terraform configuration to bootstrap the remote state management infrastructure for your AWS project.

## Overview

This configuration creates:
- **S3 Bucket**: Stores Terraform state files with versioning, encryption, and lifecycle policies
- **DynamoDB Table**: Provides state locking to prevent concurrent modifications
- **IAM User**: Service account for Terraform CI/CD with full administrative access

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.0 installed
- Appropriate AWS permissions to create S3 buckets and DynamoDB tables

## Usage

### 1. Configure Variables

Copy the example variables file and update with your values:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and set:
- `state_bucket_name`: A globally unique S3 bucket name
- `aws_region`: Your preferred AWS region
- `dynamodb_table_name`: Name for the DynamoDB lock table
- `environment`: Environment identifier (e.g., shared, prod)

### 2. Initialize Terraform

```bash
terraform init
```

### 3. Review the Plan

```bash
terraform plan
```

### 4. Apply the Configuration

```bash
terraform apply
```

### 5. Note the Outputs

After successful application, Terraform will output:
- S3 bucket name and ARN
- DynamoDB table name and ARN
- A ready-to-use backend configuration block

## Using the Remote Backend in Other Projects

After creating these resources, configure your other Terraform projects to use this remote backend:

```hcl
terraform {
  backend "s3" {
    bucket         = "your-state-bucket-name"
    key            = "path/to/your/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-locks"
    encrypt        = true
  }
}
```

Replace the values with the outputs from this bootstrap configuration.

## Important Notes

- **State Storage**: This bootstrap configuration stores its own state **locally**. Keep the `terraform.tfstate` file safe or consider migrating it to the S3 bucket after creation.
- **Bucket Naming**: S3 bucket names must be globally unique across all AWS accounts.
- **Costs**: The S3 bucket and DynamoDB table use pay-per-use pricing. Costs are typically minimal for state management.
- **Security**: The S3 bucket is configured with:
  - Versioning enabled
  - Server-side encryption (AES256)
  - Public access blocked
  - 90-day lifecycle policy for old versions

## Cleanup

To destroy these resources (use with caution):

```bash
terraform destroy
```

**Warning**: Only destroy these resources if you're certain no other Terraform projects are using them for state management.
