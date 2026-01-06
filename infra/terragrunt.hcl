locals {
  # Allow override with env vars if you later add account/region files
  aws_region = get_env("AWS_REGION", "us-east-1")
}

# Optional remote state (disabled unless you set TERRAGRUNT_DISABLE_INIT=false)
remote_state {
  disable_init = tobool(get_env("TERRAGRUNT_DISABLE_INIT", "true"))
  backend      = "s3"
  config = {
    encrypt        = true
    bucket         = get_env("TF_STATE_BUCKET", "example-tf-state-bucket")
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = get_env("TF_STATE_REGION", local.aws_region)
    dynamodb_table = get_env("TF_STATE_LOCK_TABLE", "")
  }
  generate = {
    path      = "terragrunt-state.tf"
    if_exists = "overwrite_terragrunt"
  }
}
