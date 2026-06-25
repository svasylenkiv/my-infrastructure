# Development environment configuration

locals {
  common = read_terragrunt_config("../_common/common.hcl")

  environment = "dev"
  aws_region  = "us-east-1"

  # Dev-specific tags
  dev_tags = {
    Environment = "development"
    Type        = "ephemeral"
  }

  project_name = local.common.locals.project_name
  common_tags  = merge(local.common.locals.common_tags, local.dev_tags)
  name_prefix  = "${local.project_name}-${local.environment}"
}
