# Container deploy to AWS ECS, with approval and rollback

A CoverOps Marketplace kit. Each push to your branch builds a container image and pushes it to ECR, tagged with the commit. The deploy then waits for a person to approve it in a GitHub environment, puts the image on your existing ECS service, and waits until the service is healthy. If it isn't healthy in time, ECS goes back to the version that ran before and the job fails. To roll back on purpose, run the same workflow with an earlier image tag.

There are no AWS access keys anywhere: GitHub signs in to AWS through OIDC. Terraform ≥ 1.6 or OpenTofu ≥ 1.6, AWS provider 6.x. Apache 2.0.

> Status: **v0.2.0, tested on 2026-11-18**: applied, re-planned with no changes and destroyed on a sandbox AWS account (ap-south-1), nothing left behind. Run `terraform plan` before you apply it to your account.

## What it creates

| Resource | Why | Cost |
|---|---|---|
| ECR repository, scan on push, tags immutable | Holds your images; each one is a version you can roll back to | About ₹10 a month per GB stored (estimate, at AWS list prices) |
| ECR lifecycle rule (keeps the newest `image_retention_count` tagged images, removes untagged layers after 7 days) | Stops old images piling up | Free |
| GitHub OIDC provider (unless `create_oidc_provider = false`) | Lets GitHub sign in to AWS without keys | Free |
| IAM role "push", trusted only by pushes to `github_branch` of `github_repo` | Builds and pushes images, nothing else | Free |
| IAM role "deploy", trusted only by jobs in the `github_environment` environment | Registers a task definition, updates this one ECS service, and passes only the roles you list | Free |

**Estimated monthly cost: under ₹50** (estimate) for a few hundred MB of images.

## Before you apply

1. You already have an ECS cluster and service (Fargate or EC2). The kit doesn't create them.
2. Turn on the service's deployment circuit breaker with rollback (`deployment_circuit_breaker { enable = true, rollback = true }`). That is what brings back the last healthy version.
3. In the GitHub repository settings, create the environment (`production` by default) and give it **required reviewers**. That is the approval: the deploy role trusts only jobs in that environment.

## Use

```hcl
module "deploy" {
  source = "github.com/Cover-Ops/terraform-aws-ecs-deploy?ref=v0.2.0"

  project          = "acme"
  environment      = "production"
  owner            = "platform@acme.example"
  github_repo      = "acme/api"
  ecs_cluster_name = "acme-production"
  ecs_service_name = "api"
  pass_role_arns = [
    "arn:aws:iam::123456789012:role/acme-api-task",
    "arn:aws:iam::123456789012:role/acme-api-task-execution",
  ]
}
```

Then copy [`examples/basic/.github/workflows/deploy.yml`](examples/basic/.github/workflows/deploy.yml) and [`rollback.yml`](examples/basic/.github/workflows/rollback.yml) into your application repository, and fill in the three values from the outputs. Full example: [`examples/basic`](examples/basic).

## Inputs

| Name | What it is | Default |
|---|---|---|
| `project` | Short name used in names and the Project tag | required |
| `environment` | production, staging or development | required |
| `owner` | Team or email for the Owner tag | required |
| `cost_centre` | For the CostCentre tag | `engineering` |
| `github_repo` | The only repository allowed to push and deploy, as owner/name | required |
| `github_branch` | Branch whose pushes may build images | `main` |
| `github_environment` | GitHub environment whose jobs may deploy | `production` |
| `ecs_cluster_name` | Existing ECS cluster | required |
| `ecs_service_name` | Existing ECS service | required |
| `pass_role_arns` | Task role and task execution role the deploy role may pass | required |
| `image_retention_count` | Tagged images to keep | `30` |
| `create_oidc_provider` | Create the GitHub OIDC provider; false if the account has one | `true` |
| `extra_tags` | More tags | `{}` |

## Graviton (arm64)

Fargate on arm64 costs about 20% less than x86 for the same vCPU and memory. To switch:

1. Make sure the image builds for arm64 (most official base images do).
2. Set `platform: linux/arm64` in your copy of `deploy.yml`. The build then runs on GitHub's arm64 runner, with no emulation.
3. Set `"runtimePlatform": {"cpuArchitecture": "ARM64", "operatingSystem": "LINUX"}` in the service's task definition once. Every deploy copies the current task definition, so it stays.

## Outputs

`repository_url`, `push_role_arn`, `deploy_role_arn`, `oidc_provider_arn`, `tags`.

## What it never does

- It never stores AWS keys, and it can't change any ECS service but the one you name.
- It never deploys without the approval you set on the GitHub environment.
- It never deletes your service or cluster. `terraform destroy` removes only the repository, the roles and the OIDC provider it created, and it refuses to delete a repository that still holds images (`force_delete = false`): delete them first if you mean it.

## Mandatory tags

Everything the kit creates carries `Project`, `Environment`, `Owner`, `CostCentre`, `ManagedBy` and `Kit`.
