include "root" {
  path = find_in_parent_folders()
}

locals {
  account     = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  var_region  = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  environment = local.account.locals.environment
  region      = local.var_region.locals.region
  name        = basename(get_terragrunt_dir())

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

  description         = "ALB security group"
  ingress_rules       = ["http-80-tcp", "https-443-tcp"]
  ingress_cidr_blocks = ["0.0.0.0/0"]
  egress_rules        = ["all-all"]

  name   = local.name
  vpc_id = try(dependency.vpc.outputs.vpc_id, "vpc-000000")
  tags = {
    Environment = local.environment
  }
}
