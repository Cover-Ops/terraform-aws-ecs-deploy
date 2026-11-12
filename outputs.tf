output "tags" {
  description = "The mandatory tags on everything this kit creates."
  value       = local.tags
}

output "repository_url" {
  description = "ECR repository URL. Pass it to the workflow as ecr-repository-url."
  value       = aws_ecr_repository.this.repository_url
}

output "push_role_arn" {
  description = "Role that builds and pushes images from your branch. Pass it to the workflow as push-role-arn."
  value       = aws_iam_role.this["push"].arn
}

output "deploy_role_arn" {
  description = "Role that deploys and rolls back, for jobs in the approved GitHub environment. Pass it to the workflow as deploy-role-arn."
  value       = aws_iam_role.this["deploy"].arn
}

output "oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider the roles trust."
  value       = local.oidc_provider_arn
}
