# CoverOps Marketplace kit: container deploy to AWS ECS with approvals and rollback (#15).
# GitHub signs in to AWS by OIDC (no access keys). Two roles: a push role
# that only pushes images from your main branch, and a deploy role that only
# a job in the approved GitHub environment can use, limited to one ECS
# service. Images live in a private ECR repository with immutable tags, so
# every earlier version stays there to roll back to. Apache 2.0.

data "aws_caller_identity" "this" {}
data "aws_partition" "this" {}
data "aws_region" "this" {}

locals {
  tags = merge(var.extra_tags, {
    Project     = var.project
    Environment = var.environment
    Owner       = var.owner
    CostCentre  = var.cost_centre
    ManagedBy   = "terraform"
    Kit         = "coverops/aws-ecs-deploy"
  })
  name     = "${var.project}-${var.environment}"
  arn      = "arn:${data.aws_partition.this.partition}"
  region   = data.aws_region.this.region
  acct     = data.aws_caller_identity.this.account_id
  oidc_url = "https://token.actions.githubusercontent.com"

  oidc_provider_arn = var.create_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : data.aws_iam_openid_connect_provider.github[0].arn
  service_arn       = "${local.arn}:ecs:${local.region}:${local.acct}:service/${var.ecs_cluster_name}/${var.ecs_service_name}"

  # GitHub's subject claim: who is asking.
  subjects = {
    push   = "repo:${var.github_repo}:ref:refs/heads/${var.github_branch}"
    deploy = "repo:${var.github_repo}:environment:${var.github_environment}"
  }
}

# --- Image repository ------------------------------------------------------

resource "aws_ecr_repository" "this" {
  name                 = local.name
  image_tag_mutability = "IMMUTABLE" # a tag always means the same image: safe to roll back to
  force_delete         = false

  image_scanning_configuration {
    scan_on_push = true # basic scanning, free
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = local.tags
}

resource "aws_ecr_lifecycle_policy" "this" {
  repository = aws_ecr_repository.this.name
  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Untagged layers left by failed pushes go after 7 days"
        selection    = { tagStatus = "untagged", countType = "sinceImagePushed", countUnit = "days", countNumber = 7 }
        action       = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep the newest tagged images to roll back to"
        selection    = { tagStatus = "any", countType = "imageCountMoreThan", countNumber = var.image_retention_count }
        action       = { type = "expire" }
      },
    ]
  })
}

# --- GitHub OIDC provider --------------------------------------------------

resource "aws_iam_openid_connect_provider" "github" {
  count          = var.create_oidc_provider ? 1 : 0
  url            = local.oidc_url
  client_id_list = ["sts.amazonaws.com"]
  tags           = local.tags
}

data "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 0 : 1
  url   = local.oidc_url
}

# --- Roles -----------------------------------------------------------------

data "aws_iam_policy_document" "trust" {
  for_each = local.subjects

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [each.value]
    }
  }
}

resource "aws_iam_role" "this" {
  for_each             = local.subjects
  name                 = "${local.name}-ecs-${each.key}"
  assume_role_policy   = data.aws_iam_policy_document.trust[each.key].json
  max_session_duration = 3600
  tags                 = local.tags
}

data "aws_iam_policy_document" "push" {
  statement {
    sid       = "Login"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"] # cannot be scoped to a repository
  }
  statement {
    sid = "PushToThisRepositoryOnly"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeImages",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = [aws_ecr_repository.this.arn]
  }
}

resource "aws_iam_role_policy" "push" {
  name   = "ecr-push"
  role   = aws_iam_role.this["push"].id
  policy = data.aws_iam_policy_document.push.json
}

data "aws_iam_policy_document" "deploy" {
  statement {
    sid       = "TaskDefinitions"
    actions   = ["ecs:DescribeTaskDefinition", "ecs:RegisterTaskDefinition"]
    resources = ["*"] # these calls cannot be scoped to a resource
  }
  statement {
    sid       = "ThisServiceOnly"
    actions   = ["ecs:DescribeServices", "ecs:UpdateService"]
    resources = [local.service_arn]
  }
  statement {
    sid       = "CheckTheImageExists"
    actions   = ["ecr:DescribeImages"]
    resources = [aws_ecr_repository.this.arn]
  }
  statement {
    sid       = "PassOnlyTheTaskRoles"
    actions   = ["iam:PassRole"]
    resources = var.pass_role_arns
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "deploy" {
  name   = "ecs-deploy"
  role   = aws_iam_role.this["deploy"].id
  policy = data.aws_iam_policy_document.deploy.json
}
