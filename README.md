# DevOps Technical Challenge

Infrastructure is managed with Terragrunt + official Terraform Registry modules (VPC, ALB, Security Groups, ECR, CloudWatch Logs, ECS Cluster/Service). Each stack is self-contained and composes via Terragrunt `dependency` outputs.

## Prerequisites
- Terraform 1.5.7
- Terragrunt (latest)
- AWS CLI configured (via `AWS_PROFILE`, `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY`, or SSO)
- (Optional) Remote state S3 bucket and DynamoDB lock table
	- Remote state is disabled by default. To enable, export:
		- `TF_STATE_BUCKET` — S3 bucket name
		- `TF_STATE_REGION` — e.g. `us-east-1`
		- `TF_STATE_LOCK_TABLE` — DynamoDB table name (optional)
		- `TERRAGRUNT_DISABLE_INIT=false`
	- See [infra/terragrunt.hcl](infra/terragrunt.hcl)

## Folder Structure
- infra/
	- _envcommon/ (shared module wiring)
		- [vpc.hcl](infra/_envcommon/vpc.hcl)
		- [alb.hcl](infra/_envcommon/alb.hcl)
		- [sg.hcl](infra/_envcommon/sg.hcl)
		- [ecr.hcl](infra/_envcommon/ecr.hcl)
		- [logs.hcl](infra/_envcommon/logs.hcl)
		- [ecs-cluster.hcl](infra/_envcommon/ecs-cluster.hcl)
	- dev/
		- [account.hcl](infra/dev/account.hcl)
		- us-east-1/
			- [region.hcl](infra/dev/us-east-1/region.hcl)
			- alb/
				- hello-world-alb/terragrunt.hcl
			- ecr/
				- hello-world/terragrunt.hcl
			- ecs-clusters/
				- hello-world-cluster/terragrunt.hcl
			- ecs-services/
				- hello-world-service/terragrunt.hcl
			- logs/
				- <optional log-group stacks>
			- sgs/
				- hello-world-alb-sg/terragrunt.hcl
				- hello-world-ecs-sg/terragrunt.hcl
			- vpc/
				- vpc1/terragrunt.hcl

Application container assets:
- app/
	- hello-world/
		- Dockerfile, .dockerignore, README

## Module Sources
All stacks use official modules via Git sources:
- VPC: `terraform-aws-modules/terraform-aws-vpc`
- ALB: `terraform-aws-modules/terraform-aws-alb`
- Security Group: `terraform-aws-modules/terraform-aws-security-group`
- ECR: `terraform-aws-modules/terraform-aws-ecr`
- CloudWatch Logs: `terraform-aws-modules/terraform-aws-cloudwatch` (log group submodule)
- ECS Cluster & Service: `terraform-aws-modules/terraform-aws-ecs` (service from master branch for TF 1.5.7 + AWS provider >= 6.21)

## Environment Configuration
- Set environment in [infra/dev/account.hcl](infra/dev/account.hcl)
- Set region in [infra/dev/us-east-1/region.hcl](infra/dev/us-east-1/region.hcl)
	- Ensure it matches your target region (e.g., `us-east-1`).
- Provider is generated per stack; you can also override via `AWS_REGION` env var.

## Build Order (Dev us-east-1)
Apply in this order to satisfy dependencies:
1) VPC
	 - [infra/dev/us-east-1/vpc/vpc1](infra/dev/us-east-1/vpc/vpc1)
2) Security Groups
	 - [infra/dev/us-east-1/sgs/hello-world-alb-sg](infra/dev/us-east-1/sgs/hello-world-alb-sg)
	 - [infra/dev/us-east-1/sgs/hello-world-ecs-sg](infra/dev/us-east-1/sgs/hello-world-ecs-sg)
3) ALB
	 - [infra/dev/us-east-1/alb/hello-world-alb](infra/dev/us-east-1/alb/hello-world-alb)
4) ECR
	 - [infra/dev/us-east-1/ecr/hello-world](infra/dev/us-east-1/ecr/hello-world)
5) Logs (optional)
	 - [infra/dev/us-east-1/logs](infra/dev/us-east-1/logs)
6) ECS Cluster
	 - [infra/dev/us-east-1/ecs-clusters/hello-world-cluster](infra/dev/us-east-1/ecs-clusters/hello-world-cluster)
7) ECS Service
	 - [infra/dev/us-east-1/ecs-services/hello-world-service](infra/dev/us-east-1/ecs-services/hello-world-service)

## Running Terragrunt
From each stack directory:
```bash
terragrunt init -upgrade
terragrunt validate
terragrunt plan
# terragrunt apply
```

Tips:
- For quicker `validate/plan` runs, stacks use `mock_outputs` for upstream dependencies; real values resolve on `apply`.
- Remote state: export the variables listed in Prerequisites and re-run `terragrunt init`.

## Container Image & ECR
- The ECS service references the ECR repo output and uses `:latest` by default.
- To build and push an image after creating the ECR repo:
```bash
AWS_REGION=us-east-1 ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REPO=hello-world
IMAGE=$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$REPO:latest

aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
docker build -f devops-technical-challenge/app/hello-world/Dockerfile -t $IMAGE .
docker push $IMAGE
```

## Least-Privilege IAM
- Task Execution Role: only the AWS-managed `AmazonECSTaskExecutionRolePolicy` (image pull + logs).
- Task Role: deny-by-default. Add scoped statements as needed (e.g., S3 read/write to a specific bucket/prefix). The service currently grants:
	- `s3:ListBucket` on the chosen bucket
	- `s3:GetObject`, `s3:PutObject` on `bucket/*`
	- Override bucket via `S3_BUCKET_NAME` env var before plan/apply.

## CI/CD (GitHub Actions)
- Workflow: [.github/workflows/deploy.yml](.github/workflows/deploy.yml)
- Triggers:
	- Push to `main`: build, test, build/push Docker to ECR, deploy to dev ECS
	- Pull Request: build + unit tests only
	- Workflow dispatch: manual production deployment with approval gate (GitHub Environments)
- Required GitHub Secrets:
	- `AWS_ACCESS_KEY_ID`
	- `AWS_SECRET_ACCESS_KEY`
	- `AWS_REGION` (e.g., `us-east-1`)
	- `AWS_ACCOUNT_ID`
	- `ECR_REPOSITORY` (e.g., `hello-world`)
	- `ECS_CLUSTER_NAME` (e.g., `hello-world-cluster`)
	- `ECS_SERVICE_NAME` (e.g., `hello-world-service`)
	- `SLACK_WEBHOOK_URL` (optional, for failure notifications)
- Notes:
	- The workflow uses a multi-stage Docker build and tags the image with both the commit SHA and `latest`.
	- Dev deploy job auto-registers a new task definition by cloning the current one and updating the image.
	- Production job uses `environment: production`. Configure environment protection rules and required reviewers in GitHub → Settings → Environments to enforce manual approval.

## Troubleshooting
- If `region.hcl` doesn’t match your target region, provider operations may fall back to `AWS_REGION`. Keep them consistent.
- Ensure ALB target group outputs exist before applying ECS service.
- Confirm ECR image is pushed (and tag matches) before first ECS service rollout.
