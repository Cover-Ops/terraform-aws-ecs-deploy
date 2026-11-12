# Changelog

## 0.1.0 (2026-11-12)

- First release: an ECR repository with a lifecycle rule, and two GitHub OIDC roles. The push role builds and pushes from one branch. The deploy role deploys and rolls back one ECS service, only from an approved GitHub environment.
- A reusable workflow for build, approval, deploy and rollback. ECS's deployment circuit breaker returns the service to its last healthy version.
- Mandatory tags on everything: Project, Environment, Owner, CostCentre, ManagedBy, Kit.
- Sandbox test: **passed 2026-11-12** (AWS ap-south-1: apply, re-plan with no changes, destroy, nothing left).
