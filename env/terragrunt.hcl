# Root Terragrunt configuration

# Configure remote state
remote_state {
  backend = "s3"
  
  config = {
    bucket         = "terraform-state-${get_aws_account_id()}"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
  
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
}

# Generate provider configuration
generate "provider" {
  path      = "provider.tf" 
  if_exists = "overwrite"
  contents  = <<-EOF
    terraform {
      required_version = ">= 1.0"
      required_providers {
        aws = {
          source  = "hashicorp/aws"
          version = "~> 5.0"
        }
      }
    }
    
    provider "aws" {
      region = var.aws_region
      
      default_tags {
        tags = {
          Environment = var.environment
          ManagedBy   = "terragrunt"
        }
      }
    }
  EOF
}
