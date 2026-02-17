# ECR Module

Creates one Amazon ECR (Elastic Container Registry) repository per project name, each with an image lifecycle policy.

## Lifecycle Policy

Each repository is configured with the following image retention rules:

| Tag Pattern  | Retention                          |
|--------------|------------------------------------|
| `*RELEASE`   | Kept indefinitely                  |
| `*SNAPSHOT`  | Only the latest 5 images are kept  |

Images with tags ending in `RELEASE` (e.g., `v1.0.0-RELEASE`) are never expired. Images with tags ending in `SNAPSHOT` (e.g., `v1.0.0-SNAPSHOT`) are automatically expired once there are more than 5, keeping only the most recent 5.

## Usage

```hcl
module "ecr" {
  source = "./modules/ecr"

  project_names = ["my-api", "my-frontend", "my-worker"]

  tags = {
    Environment = "dev"
    Project     = "Workshop Platform"
  }
}
```

This creates three ECR repositories (`my-api`, `my-frontend`, `my-worker`), each with the lifecycle policy above.

## Resources Created

| Resource                     | Count              |
|------------------------------|--------------------|
| `aws_ecr_repository`        | 1 per project name |
| `aws_ecr_lifecycle_policy`  | 1 per project name |

All repositories are created with:
- **Image scanning on push** enabled
- **Mutable** image tags
- **Force delete** disabled (repositories with images cannot be accidentally destroyed)

## Variables

| Name            | Type           | Default | Required | Description                                      |
|-----------------|----------------|---------|----------|--------------------------------------------------|
| `project_names` | `list(string)` | n/a     | yes      | List of project names to create repositories for |
| `tags`          | `map(string)`  | `{}`    | no       | Tags to apply to all ECR repositories            |

## Outputs

| Name              | Description                                    |
|-------------------|------------------------------------------------|
| `repository_urls` | Map of project names to ECR repository URLs    |
| `repository_arns` | Map of project names to ECR repository ARNs    |

### Example output

```
repository_urls = {
  "my-api"      = "123456789012.dkr.ecr.eu-west-1.amazonaws.com/my-api"
  "my-frontend" = "123456789012.dkr.ecr.eu-west-1.amazonaws.com/my-frontend"
  "my-worker"   = "123456789012.dkr.ecr.eu-west-1.amazonaws.com/my-worker"
}
```
