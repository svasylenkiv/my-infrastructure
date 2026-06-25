# ДЕНЬ 2: Конфігурація Terragrunt

Покрокова інструкція для цього проєкту. Оновлено під **Terragrunt v1.0.8** та **Terraform v1.11+**.

## Передумови

```bash
terragrunt --version   # v1.0.8+
terraform version      # v1.11+ (рекомендовано v1.15+)
aws sts get-caller-identity   # AWS credentials налаштовані
```

Усі команди нижче запускайте з кореня проєкту, якщо не вказано інше:

```bash
cd my-infrastructure/
```

---

## Структура проєкту

```
my-infrastructure/
├── docs/
│   └── DAY-2.md
├── modules/
│   ├── vpc/
│   └── compute/
└── env/
    ├── terragrunt.hcl          # кореневий конфіг (remote state, provider)
    ├── _common/
    │   └── common.hcl          # спільні змінні
    ├── dev/
    │   ├── terragrunt.hcl      # конфіг середовища dev
    │   ├── vpc/
    │   │   └── terragrunt.hcl
    │   └── compute/
    │       └── terragrunt.hcl
    ├── staging/
    └── prod/
```

---

## Важливо: як створювати файли

**Рекомендовано** — редагувати `.hcl` файли безпосередньо в IDE (Cursor/VS Code).

Якщо використовуєте `cat` у терміналі:

| Помилка | Правильно |
|---------|-----------|
| `<< EOF` без лапок | `<< 'EOF'` — лапки з **обох** боків |
| `<< 'EOF` без закриваючої `'` | `<< 'EOF'` |
| Закриття `EOF'` | окремий рядок просто `EOF` |
| `"\${path_relative_to_include()}"` у `.hcl` | `"${path_relative_to_include()}"` — без `\` |
| `cat > env/...` з папки `env/` | спочатку `cd my-infrastructure/` |

`'\$'` потрібен **тільки** в bash heredoc **без** лапок навколо `EOF`. У `.hcl` файлах backslash перед `$` — помилка.

---

## Крок 1: Кореневий `env/terragrunt.hcl`

Файл: `env/terragrunt.hcl`

```hcl
# Root Terragrunt configuration
# This file will be included by all child modules

remote_state {
  backend = "s3"

  config = {
    bucket       = "terraform-state-${get_aws_account_id()}"
    key          = "${path_relative_to_include()}/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite"
  contents  = <<-EOF_PROVIDER
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
  EOF_PROVIDER
}
```

### Нюанси для Terragrunt v1.0.8

- **Не додавайте** блок `terraform { required_version ... }` на кореневому рівні — Terragrunt його не підтримує.
- Версії Terraform і провайдерів задаються в `generate "provider"`.
- **`use_lockfile = true`** — сучасне блокування state в S3 (Terraform 1.11+).
- **`dynamodb_table`** — застарілий параметр; Terraform покаже warning, але працює.

---

## Крок 2: Спільний конфіг `env/_common/common.hcl`

```hcl
# Common configuration used by all environments

locals {
  aws_region  = "us-east-1"
  aws_profile = "default"
  environment = "dev"

  project_name = "my-infrastructure"
  team_name    = "platform-team"

  common_tags = {
    Project     = local.project_name
    Team        = local.team_name
    Environment = local.environment
    ManagedBy   = "terragrunt"
  }

  name_prefix = "${local.project_name}-${local.environment}"
}
```

---

## Крок 3: Конфіг середовища `env/dev/terragrunt.hcl`

```hcl
# Development environment configuration

locals {
  common = read_terragrunt_config("../_common/common.hcl")

  environment = "dev"
  aws_region  = "us-east-1"

  dev_tags = {
    Environment = "development"
    Type        = "ephemeral"
  }

  project_name = local.common.locals.project_name
  common_tags  = merge(local.common.locals.common_tags, local.dev_tags)
  name_prefix  = "${local.project_name}-${local.environment}"
}
```

---

## Крок 4: VPC модуль `env/dev/vpc/terragrunt.hcl`

```hcl
# VPC module for development environment

include "root" {
  path = find_in_parent_folders("terragrunt.hcl")
}

locals {
  common = read_terragrunt_config(find_in_parent_folders("_common/common.hcl"))
  dev    = read_terragrunt_config(find_in_parent_folders("terragrunt.hcl", "dev"))

  vpc_cidr = "10.0.0.0/16"
  name     = "${local.dev.locals.name_prefix}-vpc"

  availability_zones = [
    "${local.dev.locals.aws_region}a",
    "${local.dev.locals.aws_region}b",
  ]
}

terraform {
  source = "../../../modules/vpc"
}

inputs = {
  vpc_cidr           = local.vpc_cidr
  name               = local.name
  availability_zones = local.availability_zones
  tags               = local.dev.locals.common_tags
  aws_region         = local.dev.locals.aws_region
  environment        = local.dev.locals.environment
}
```

> **Альтернатива (теж працює):** замість `find_in_parent_folders` можна вказати відносні шляхи:
> `path = "../../terragrunt.hcl"`, `read_terragrunt_config("../terragrunt.hcl")` тощо.

---

## Крок 5: Compute модуль `env/dev/compute/terragrunt.hcl`

```hcl
# Compute module for development environment

include "root" {
  path = find_in_parent_folders("terragrunt.hcl")
}

locals {
  common = read_terragrunt_config(find_in_parent_folders("_common/common.hcl"))
  dev    = read_terragrunt_config(find_in_parent_folders("terragrunt.hcl", "dev"))

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
  aws_region     = local.dev.locals.aws_region
  environment    = local.dev.locals.environment
}
```

---

## Крок 6: Terraform модулі

### `modules/vpc/`

**main.tf**, **variables.tf**, **outputs.tf** — див. офіційний tutorial або створіть мінімальний VPC модуль з `aws_vpc` і `aws_subnet`.

### `modules/compute/`

Мінімальний модуль з `aws_instance` та data source для Amazon Linux AMI.

---

## Крок 7: Перевірка конфігурації

### 7.1 Валідація синтаксису HCL

```bash
cd env/dev/vpc
terragrunt hcl validate
```

Очікуваний результат: без помилок (exit code 0).

### 7.2 Перегляд фінального конфігу (JSON)

У Terragrunt v1.0.8 команда `render-json` **замінена**:

```bash
# ❌ Застаріло
terragrunt render-json

# ✅ Правильно
terragrunt render --json

# Лише remote_state (читабельно)
terragrunt render --json 2>/dev/null | python3 -c \
  "import sys,json; print(json.dumps(json.load(sys.stdin)['remote_state'], indent=2))"
```

### 7.3 Ініціалізація

```bash
cd env/dev/vpc

# Перший запуск — створить S3 bucket автоматично
terragrunt init --backend-bootstrap

# Наступні запуски
terragrunt init
```

#### Очікувані результати

| Ситуація | Результат | Дія |
|----------|-----------|-----|
| S3 bucket не існує | `NoSuchBucket` | `terragrunt init --backend-bootstrap` |
| `dynamodb_table` у конфігу | Warning `Deprecated Parameter` | Замінити на `use_lockfile = true` |
| Успішний init | `Successfully configured the backend "s3"!` | Все ОК, можна `plan` |

### 7.4 Граф залежностей

```bash
cd env/dev
terragrunt dag graph
```

---

## Корисні команди (Terragrunt v1)

| Стара команда | Нова команда (v1.0.8) |
|---------------|----------------------|
| `terragrunt render-json` | `terragrunt render --json` |
| `terragrunt validate-all` | `terragrunt run --all validate` |
| `terragrunt graph-dependencies` | `terragrunt dag graph` |
| `terragrunt plan` | `terragrunt plan` (shortcut працює) |
| `terragrunt init` | `terragrunt init` (shortcut працює) |

---

## Типові помилки

### `bad substitution` при `cat`

```bash
# ❌ bash намагається розгорнути ${get_aws_account_id()}
cat > env/terragrunt.hcl << EOF

# ✅
cat > env/terragrunt.hcl << 'EOF'
```

### `Invalid escape sequence` у HCL

```hcl
# ❌
key = "\${path_relative_to_include()}/terraform.tfstate"

# ✅
key = "${path_relative_to_include()}/terraform.tfstate"
```

### `Unsupported argument "required_version"`

Блок `terraform { required_version ... }` на кореневому рівні `env/terragrunt.hcl` не підтримується. Перенесіть у `generate "provider"`.

### `env/terragrunt.hcl: No such file or directory`

Ви в неправильній директорії. Перевірте:

```bash
pwd   # має бути .../my-infrastructure
ls env/terragrunt.hcl
```

### Порожній `terragrunt.hcl` після `cat`

Heredoc зламаний — bash не записав вміст. Відновіть файл з IDE або з цього документа.

---

## Remote State: як це працює

Після `include "root"` у дочірніх модулях Terragrunt генерує `backend.tf`:

```
s3://terraform-state-<AWS_ACCOUNT_ID>/
├── dev/vpc/terraform.tfstate
├── dev/vpc/terraform.tfstate.tflock   # при use_lockfile = true
└── dev/compute/terraform.tfstate
```

| Параметр | Призначення |
|----------|-------------|
| `bucket` | S3 bucket для state |
| `key` | Шлях до файлу state в bucket |
| `region` | AWS регіон bucket |
| `encrypt` | Шифрування state |
| `use_lockfile` | Блокування через `.tflock` файл у S3 |

---

## Контрольний список

### Теорія
- [ ] Розумію блоки: `remote_state`, `generate`, `inputs`, `locals`, `include`
- [ ] Знаю функції: `get_terragrunt_dir`, `path_relative_to_include`, `find_in_parent_folders`, `get_aws_account_id`, `merge`

### Практика
- [ ] `env/terragrunt.hcl` створено
- [ ] `env/_common/common.hcl` створено
- [ ] `env/dev/terragrunt.hcl` створено
- [ ] `env/dev/vpc/terragrunt.hcl` створено
- [ ] `env/dev/compute/terragrunt.hcl` створено
- [ ] Модулі `modules/vpc` і `modules/compute` створено
- [ ] `terragrunt hcl validate` проходить
- [ ] `terragrunt init` успішний

---

## Підготовка до ДНЯ 3

На ДЕНЬ 3:
1. Переконатися, що S3 bucket існує (або `--backend-bootstrap`)
2. Увімкнути versioning на S3 bucket
3. Запустити `terragrunt plan` / `apply`
4. Розібратися з IAM доступом до state

---

## Посилання

- [Terragrunt config blocks](https://terragrunt.gruntwork.io/docs/reference/config-blocks/)
- [Built-in functions](https://terragrunt.gruntwork.io/docs/reference/built-in-functions/)
- [Terragrunt v1 CLI migration](https://docs.terragrunt.com/migrate/cli-redesign/)
- [Terraform S3 backend](https://developer.hashicorp.com/terraform/language/backend/s3)
