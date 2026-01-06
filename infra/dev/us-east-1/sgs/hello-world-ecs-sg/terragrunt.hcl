include "root" {
  path = find_in_parent_folders()
}

locals {
  account     = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  var_region  = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  environment = local.account.locals.environment
  region      = local.var_region.locals.region
  name        = basename(get_terragrunt_dir())
  app_port    = 8080

}


include "envcommon" { path = "${get_parent_terragrunt_dir()}/../../../../_envcommon/sg.hcl" }

dependency "vpc" {
  config_path                             = "../../vpc/vpc1"
  skip_outputs                            = true
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    vpc_id = "vpc-000000"
  }
}

inputs = {
  name     = local.name
  vpc_id   = try(dependency.vpc.outputs.vpc_id, "vpc-000000")
  app_port = local.app_port
  ingress_with_source_security_group_id = [
    {
      rule                     = "http-80-tcp"
      source_security_group_id = try(dependency.sg_alb.outputs.security_group_id, "sg-000000")
      description              = "From ALB"
      from_port                = local.app_port
      to_port                  = local.app_port
      protocol                 = "tcp"
    }
  ]
  egress_rules = ["all-all"]
  tags = {
    Environment = local.environment
  }
}
