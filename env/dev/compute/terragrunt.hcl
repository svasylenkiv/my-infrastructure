# Compute module for development environment

include "root" {
  path = "../../terragrunt.hcl"
}

locals {
  common = read_terragrunt_config("../../_common/common.hcl")
  dev    = read_terragrunt_config("../terragrunt.hcl")

  name           = "${local.dev.locals.name_prefix}-compute"
  instance_type  = "t3.micro"
  instance_count = 1
}

terraform {
  source = "../../../modules/compute"
}

inputs = {
  name           = local.name
  instance_type  = local.instance_type
  instance_count = local.instance_count
  tags           = local.dev.locals.common_tags
}
