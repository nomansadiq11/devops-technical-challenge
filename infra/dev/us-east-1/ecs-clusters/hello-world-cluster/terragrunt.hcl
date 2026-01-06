include "root" {
  path = find_in_parent_folders()
}

locals {
  account     = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  var_region  = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  environment = try(local.account.locals.environment, "dev")
  region      = try(local.var_region.locals.region, get_env("AWS_REGION", "us-east-1"))
  name        = basename(get_terragrunt_dir())
}

# Keep stacks self-contained with generated provider
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region = "${local.region}"
  default_tags {
    tags = {
      Environment = "${local.environment}"
      Project     = "devops-technical-challenge"
      ManagedBy   = "terragrunt"
    }
  }
}
EOF
}

include "envcommon" {
  path = "${get_parent_terragrunt_dir()}/../../../../_envcommon/ecs-cluster.hcl"
}

inputs = {
  name               = local.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]
  default_capacity_provider_strategy = [{
    capacity_provider = "FARGATE"
    weight            = 1
    base              = 0
  }]
  settings = [{
    name  = "containerInsights"
    value = "enabled"
  }]
  tags = {
    Environment = local.environment
  }
}
