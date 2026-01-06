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
  s3_bucket_name = get_env("S3_BUCKET_NAME", "hello-world-dev-bucket")
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
  source = "git::https://github.com/terraform-aws-modules/terraform-aws-ecs.git//modules/service?ref=master"
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


# ECR (to source container image)
dependency "ecr" {
  config_path                             = "../../ecr/hello-world"
  skip_outputs                            = true
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    repository_url = "123456789012.dkr.ecr.${local.region}.amazonaws.com/hello-world"
  }
}


inputs = {
  name        = local.name
  cluster_arn = try(dependency.cluster.outputs.arn, "arn:aws:ecs:${local.region}:123456789012:cluster/mock")

  # Task sizing
  cpu    = 512
  memory = 1024

  # Container definition
  container_definitions = {
    app = {
      essential                 = true
      image                     = try("${dependency.ecr.outputs.repository_url}:latest", "public.ecr.aws/docker/library/openjdk:17-jdk-slim")
      enable_cloudwatch_logging = true
      port_mappings = [
        {
          name          = "app"
          containerPort = local.container_port
          protocol      = "tcp"
        }
      ]
    }
  }

  # Networking
  subnet_ids            = try(dependency.vpc.outputs.private_subnets, ["subnet-000001", "subnet-000002"])
  security_group_ids    = [try(dependency.sg_ecs.outputs.security_group_id, "sg-000000")]
  create_security_group = false
  assign_public_ip      = false

  # ALB attachment
  load_balancer = {
    service = {
      target_group_arn = try(values(dependency.alb.outputs.target_groups)[0].arn, "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/mock/123")
      container_name   = "app"
      container_port   = local.container_port
    }
  }

  # Autoscaling
  enable_autoscaling       = true
  autoscaling_min_capacity = 1
  autoscaling_max_capacity = 3
  autoscaling_policies = {
    cpu = {
      policy_type = "TargetTrackingScaling"
      target_tracking_scaling_policy_configuration = {
        target_value = 70
        predefined_metric_specification = {
          predefined_metric_type = "ECSServiceAverageCPUUtilization"
        }
      }
    }
  }

  # IAM: Least-privilege roles
  create_task_exec_iam_role = true
  create_task_exec_policy   = true
  task_exec_iam_statements  = []
  task_exec_secret_arns     = []
  task_exec_ssm_param_arns  = []

  create_tasks_iam_role = true
  tasks_iam_role_statements = [
    {
      sid     = "S3ListBucket"
      effect  = "Allow"
      actions = ["s3:ListBucket"]
      resources = [
        "arn:aws:s3:::${local.s3_bucket_name}"
      ]
    },
    {
      sid    = "S3ObjectRW"
      effect = "Allow"
      actions = [
        "s3:GetObject",
        "s3:PutObject"
      ]
      resources = [
        "arn:aws:s3:::${local.s3_bucket_name}/*"
      ]
    }
  ]

  tags = {
    Environment = local.environment
  }
}
