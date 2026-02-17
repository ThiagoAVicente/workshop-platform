# ECR Repositories for workshop projects
module "ecr" {
  source = "./modules/ecr"
  count  = length(var.ecr_project_names) > 0 ? 1 : 0

  project_names = var.ecr_project_names
  tags          = var.tags
}
