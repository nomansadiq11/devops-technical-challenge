terraform {
  # Use official VPC module to avoid path complexity
  source = "git::https://github.com/terraform-aws-modules/terraform-aws-vpc.git?ref=v5.8.1"
}

inputs = {}
