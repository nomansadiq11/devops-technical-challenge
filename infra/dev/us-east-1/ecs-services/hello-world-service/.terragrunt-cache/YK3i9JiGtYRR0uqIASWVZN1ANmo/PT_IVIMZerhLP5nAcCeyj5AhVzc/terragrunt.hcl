include "root" {
  path = find_in_parent_folders()
}

locals {
  account        = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  var_region     = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  environment    = try(local.account.locals.environment, "dev")
  region         = try(local.var_region.locals.region, get_env("AWS_REGION", "us-east-1"))
  name           = basename(get_terragrunt_dir())
  container_port = 8080
}

# Keep stacks self-contained with generated provider
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

terraform {
  source = "./module"
}

# Dependencies: cluster, vpc, sg, alb
# Cluster
dependency "cluster" {
  config_path                             = "../../ecs-clusters/hello-world-cluster"
  skip_outputs                            = true
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    arn  = "arn:aws:ecs:us-east-1:123456789012:cluster/mock"
    name = "hello-world-cluster"
  }
}

# VPC
dependency "vpc" {
  config_path                             = "../../vpc/vpc1"
  skip_outputs                            = true
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    private_subnets = ["subnet-000001", "subnet-000002"]
    vpc_id          = "vpc-000000"
  }
}

# ECS SG
dependency "sg_ecs" {
  config_path                             = "../../sgs/hello-world-ecs-sg"
  skip_outputs                            = true
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    security_group_id = "sg-000000"
  }
}

# ALB (to get target group)
dependency "alb" {
  config_path                             = "../../alb/hello-world-alb"
  skip_outputs                            = true
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    target_groups = {
      mock = {
        arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/mock/123"
      }
    }
  }
}



inputs = {
  name         = local.name
  cluster_arn  = try(dependency.cluster.outputs.arn, "arn:aws:ecs:${local.region}:123456789012:cluster/mock")
  cluster_name = try(dependency.cluster.outputs.name, "hello-world-cluster")

  container_image = "public.ecr.aws/docker/library/openjdk:17-jdk-slim"
  cpu             = 512
  memory          = 1024
  container_port  = local.container_port

  # Networking
  subnet_ids         = try(dependency.vpc.outputs.private_subnets, ["subnet-000001", "subnet-000002"])
  security_group_ids = [try(dependency.sg_ecs.outputs.security_group_id, "sg-000000")]

  # ALB attachment
  target_group_arn = try(values(dependency.alb.outputs.target_groups)[0].arn, "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/mock/123")

  # Autoscaling
  asg_min_capacity = 1
  asg_max_capacity = 3
  asg_cpu_target   = 70

  tags = {
    Environment = local.environment
  }
}
