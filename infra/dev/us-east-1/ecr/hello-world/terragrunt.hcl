include "root" {
  path = find_in_parent_folders()
}

locals {
  account    = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  var_region = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  # root_cfg    = read_terragrunt_config(find_in_parent_folders("terragrunt.hcl"))
  environment = local.account.locals.environment
  region      = local.var_region.locals.region
  repo_name   = basename(get_terragrunt_dir())


}

include "envcommon" { path = "${get_parent_terragrunt_dir()}/../../../../_envcommon/ecr.hcl" }

inputs = {
  repository_name  = local.repo_name
  force_delete     = true
  scan_on_push     = true
  lifecycle_policy = null
  tags = {
    Environment = local.environment
  }
}
