# VPC module for development environment

include "root" {
  path = "../../terragrunt.hcl"
}

locals {
  common = read_terragrunt_config("../../_common/common.hcl")
  dev    = read_terragrunt_config("../terragrunt.hcl")

  vpc_cidr = "10.0.0.0/16"
  name     = "${local.dev.locals.name_prefix}-vpc"

  availability_zones = [
    "${local.dev.locals.aws_region}a",
    "${local.dev.locals.aws_region}b",
  ]
}

# Configure Terraform for VPC module
terraform {
  source = "../../../modules/vpc"
}

# Input variables for VPC module
inputs = {
  vpc_cidr           = local.vpc_cidr
  name               = local.name
  availability_zones = local.availability_zones
  tags               = local.dev.locals.common_tags
}
