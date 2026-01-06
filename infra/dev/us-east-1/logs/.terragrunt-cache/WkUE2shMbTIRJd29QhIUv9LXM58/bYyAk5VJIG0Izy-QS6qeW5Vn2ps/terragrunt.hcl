locals {
  environment = "dev"
}

include "root" { path = find_in_parent_folders() }
include "envcommon" { path = "${get_parent_terragrunt_dir()}/../../../_envcommon/logs.hcl" }

inputs = {
  name              = "/ecs/java-app-dev"
  retention_in_days = 7
  tags = {
    Environment = local.environment
  }
}
