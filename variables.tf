variable "project" {
  description = "Short name of the product or company, used in names and the Project tag (lowercase, digits, hyphens)."
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,30}$", var.project))
    error_message = "Use 2-31 characters: lowercase letters, digits and hyphens, starting with a letter."
  }
}

variable "environment" {
  description = "Which environment the service runs in: production, staging or development."
  type        = string
  validation {
    condition     = contains(["production", "staging", "development"], var.environment)
    error_message = "Use production, staging or development."
  }
}

variable "owner" {
  description = "Who answers for spend here: a team or a person's email. Goes in the Owner tag."
  type        = string
}

variable "cost_centre" {
  description = "Cost centre or budget line for the CostCentre tag, e.g. engineering."
  type        = string
  default     = "engineering"
}

variable "github_repo" {
  description = "The only GitHub repository allowed to push images and deploy, as owner/name, e.g. acme/api."
  type        = string
  validation {
    condition     = can(regex("^[A-Za-z0-9-]+/[A-Za-z0-9._-]+$", var.github_repo))
    error_message = "Use owner/name, e.g. acme/api."
  }
}

variable "github_branch" {
  description = "Branch whose pushes may build and push images."
  type        = string
  default     = "main"
}

variable "github_environment" {
  description = "The GitHub environment whose jobs may deploy and roll back. Give it required reviewers in the repository settings: that is the approval."
  type        = string
  default     = "production"
}

variable "ecs_cluster_name" {
  description = "Name of the existing ECS cluster the service runs in."
  type        = string
}

variable "ecs_service_name" {
  description = "Name of the existing ECS service to deploy. Turn on its deployment circuit breaker with rollback (see README)."
  type        = string
}

variable "pass_role_arns" {
  description = "The task role and task execution role ARNs of the service's task definition. The deploy role may pass only these, and only to ECS tasks."
  type        = list(string)
  validation {
    condition     = length(var.pass_role_arns) > 0
    error_message = "Give at least the task execution role ARN."
  }
}

variable "image_retention_count" {
  description = "How many tagged images to keep in the repository; older ones are deleted. Each one is a version you can roll back to."
  type        = number
  default     = 30
}

variable "create_oidc_provider" {
  description = "Create the GitHub OIDC provider. Set false if the account already has one for token.actions.githubusercontent.com (for example from the Terraform pipeline kit)."
  type        = bool
  default     = true
}

variable "extra_tags" {
  description = "More tags to add to everything this kit creates."
  type        = map(string)
  default     = {}
}
