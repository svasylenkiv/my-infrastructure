# Common configuration used by all environments

locals {
  # AWS Configuration
  aws_region = "us-east-1"
  aws_profile = "default"
  
  # Default environment
  environment = "dev"
  
  # Project information
  project_name = "my-infrastructure"
  team_name    = "platform-team"
  
  # Default tags applied to all resources
  common_tags = {
    Project     = local.project_name
    Team        = local.team_name
    Environment = local.environment
    ManagedBy   = "terragrunt"
    CreatedAt   = timestamp()
  }
  
  # Default naming convention
  name_prefix = "${local.project_name}-${local.environment}"
}

