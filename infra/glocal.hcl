locals {
  # Automatically load account-level variables
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))

  # Automatically load region-level variables
  region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  # Extract the variables we need for easy access
  account_id   = local.account_vars.locals.aws_account_id
  account_name = local.account_vars.locals.account_name
  iam_role     = local.account_vars.locals.aws_iam_role
  aws_region   = local.region_vars.locals.aws_region
  bucket_name  = "grid-tf-state"
}

# Configure Terragrunt to automatically store tfstate files in an S3 bucket
remote_state {
  disable_init = tobool(get_env("TERRAGRUNT_DISABLE_INIT", "false"))

  backend = "s3"
  config = {
    encrypt        = true
    bucket         = local.bucket_name
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "grid-tf-lock"
  }
  generate = {
    path      = "terragrunt-state.tf"
    if_exists = "overwrite_terragrunt"
  }
}

# Generate an AWS provider block
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region = "${local.aws_region}"
  version = ">= 3.5, < 5.48"
%{if local.iam_role != ""~}
  assume_role {
    role_arn    = "${local.iam_role}"
  }
%{endif}
}
EOF
}



inputs = merge(
  local.account_vars.locals,
  local.region_vars.locals
)
