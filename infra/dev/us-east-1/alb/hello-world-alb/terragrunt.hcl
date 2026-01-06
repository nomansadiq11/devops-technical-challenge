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

include "envcommon" { path = "${get_parent_terragrunt_dir()}/../../../../_envcommon/alb.hcl" }

dependency "vpc" {
  config_path                             = "../../vpc/vpc1"
  skip_outputs                            = true
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    vpc_id         = "vpc-000000"
    public_subnets = ["subnet-000001", "subnet-000002"]
  }
}

dependency "sg_alb" {
  config_path                             = "../../sgs/hello-world-alb-sg"
  skip_outputs                            = true
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    security_group_id = "sg-000000"
  }
}

inputs = {
  name            = local.name
  vpc_id          = try(dependency.vpc.outputs.vpc_id, "vpc-000000")
  subnets         = try(dependency.vpc.outputs.public_subnets, ["subnet-000001", "subnet-000002"])
  security_groups = [try(dependency.sg_alb.outputs.security_group_id, "sg-000000")]

  target_groups = [{
    name_prefix      = "tg-"
    backend_protocol = "HTTP"
    backend_port     = 80
    target_type      = "ip"
    health_check = {
      enabled             = true
      interval            = 30
      healthy_threshold   = 2
      unhealthy_threshold = 2
      path                = "/"
      matcher             = "200-399"
    }
  }]

  listeners = [{
    port     = 80
    protocol = "HTTP"
    default_action = {
      type               = "forward"
      target_group_index = 0
    }
  }]

  tags = {
    Environment = local.environment
  }
}
