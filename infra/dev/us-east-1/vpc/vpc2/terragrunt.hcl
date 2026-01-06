include "root" {
  path = find_in_parent_folders()
}

locals {
  account    = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  var_region = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  # root_cfg    = read_terragrunt_config(find_in_parent_folders("terragrunt.hcl"))
  environment = local.account.locals.environment
  region      = local.var_region.locals.region
  name        = basename(get_terragrunt_dir())

  cidr            = "10.0.0.0/16"
  azs             = ["us-east-1a", "us-east-1b"]
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.101.0/24", "10.0.102.0/24"]
}

include "envcommon" {
  path = "${get_parent_terragrunt_dir()}/../../../../_envcommon/vpc.hcl"
}

# Generate provider config so each stack stays self-contained
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

inputs = {
  name = local.name
  cidr = local.cidr

  azs             = local.azs
  public_subnets  = local.public_subnets
  private_subnets = local.private_subnets

  enable_nat_gateway   = true
  single_nat_gateway   = true # cost optimization
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Environment = local.environment
  }
}
