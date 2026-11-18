# Deploys acme's API image to its existing ECS service in Mumbai.
# Apply once from a laptop; the workflows in .github/workflows do the rest.
locals {
  project     = "acme"
  environment = "production"
  owner       = "platform@acme.example"
}

provider "aws" {
  region = "ap-south-1"

  default_tags {
    tags = {
      Project     = local.project
      Environment = local.environment
      Owner       = local.owner
      CostCentre  = "engineering"
      ManagedBy   = "terraform"
    }
  }
}

module "deploy" {
  source = "../.."
  # After publishing: source = "github.com/Cover-Ops/terraform-aws-ecs-deploy?ref=v0.2.0"

  project          = local.project
  environment      = local.environment
  owner            = local.owner
  github_repo      = "acme/api"
  ecs_cluster_name = "acme-production"
  ecs_service_name = "api"
  pass_role_arns = [
    "arn:aws:iam::123456789012:role/acme-api-task",
    "arn:aws:iam::123456789012:role/acme-api-task-execution",
  ]
}

output "workflow_inputs" {
  description = "Paste these into .github/workflows/deploy.yml and rollback.yml."
  value = {
    push-role-arn      = module.deploy.push_role_arn
    deploy-role-arn    = module.deploy.deploy_role_arn
    ecr-repository-url = module.deploy.repository_url
  }
}
