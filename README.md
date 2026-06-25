# My Infrastructure

Terragrunt-based Infrastructure as Code project for managing cloud resources.

## Structure

- `modules/` - Terraform modules
- `env/` - Environment-specific configurations
- `dev/` - Development environment
- `prod/` - Production environment
- `staging/` - Staging environment

## Getting Started

1. Install Terraform (v1.11+) and Terragrunt (v1.0.8+)
2. Configure AWS credentials (`aws sts get-caller-identity`)
3. Follow the day-by-day guides in `docs/`
4. Run `terragrunt init --backend-bootstrap` from a module directory (e.g. `env/dev/vpc`)
5. Run `terragrunt plan`

## Documentation

- [ДЕНЬ 2: Конфігурація Terragrunt](docs/DAY-2.md) — покрокова інструкція з виправленнями для Terragrunt v1
