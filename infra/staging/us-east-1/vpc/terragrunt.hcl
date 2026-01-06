locals {
  environment = "staging"
  region      = "us-east-1"
  name        = "staging-vpc"

  cidr            = "10.1.0.0/16"
  azs             = ["us-east-1a", "us-east-1b"]
  public_subnets  = ["10.1.1.0/24", "10.1.2.0/24"]
  private_subnets = ["10.1.101.0/24", "10.1.102.0/24"]
}

include "root" {
  path = find_in_parent_folders()
}

include "envcommon" {
  path = "${get_parent_terragrunt_dir()}/../../../_envcommon/vpc.hcl"
}

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
  single_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Environment = local.environment
  }
}
