# infra/ — modular Terraform with dev/prod environments

```
infra/
  modules/
    network/   # VPC, subnets, NAT, routing, ALB + ALB security group
    ecs/       # ECS cluster, task definition, service, ECS SG, IAM, logs
    rds/       # DB subnet group, RDS instance, RDS SG, Secrets Manager
  envs/
    dev/       # dev sizing + backend + tfvars
    prod/      # prod sizing + backend + tfvars
```

Each environment is a separate Terraform root module (its own state,
its own backend, its own provider block) that wires the three shared
modules together with different inputs. No resources or state are
shared between `dev` and `prod` — they are entirely independent stacks
that happen to reuse the same module code.

## Module responsibilities

| Module    | Owns                                                                          | Key outputs consumed elsewhere |
|-----------|--------------------------------------------------------------------------------|---------------------------------|
| `network` | VPC, public/private-app/private-db subnets, IGW, NAT, ALB, ALB security group  | `vpc_id`, subnet ID lists, `alb_security_group_id`, `target_group_arn` |
| `ecs`     | ECS cluster, Fargate task def + service, ECS task security group, IAM roles, log group | `ecs_tasks_security_group_id`, `cluster_name` |
| `rds`     | DB subnet group, RDS instance, RDS security group, Secrets Manager credentials | `db_secret_arn`, `db_endpoint` |

Wiring in each `envs/<env>/main.tf`:

```
network  →  alb_security_group_id, target_group_arn  →  ecs
ecs      →  ecs_tasks_security_group_id               →  rds   (SG-to-SG ingress rule only)
rds      →  db_secret_arn                             →  ecs   (injected as container env vars)
```

RDS's security group allows inbound only from the ECS tasks' security
group — never a CIDR block — so the database is reachable only from
Fargate tasks in that environment, same as the single-environment
version of this stack.

## What differs between dev and prod

| Setting                     | dev                          | prod                          |
|------------------------------|-------------------------------|---------------------------------|
| Backend state key            | `myapp/dev/terraform.tfstate` | `myapp/prod/terraform.tfstate` |
| Lock table                   | `terraform-locks-dev`         | `terraform-locks-prod`         |
| NAT Gateways                 | 1 shared (`single_nat_gateway = true`) | 1 per AZ (HA)          |
| ECS task size                | 256 CPU / 512 MiB, 1 task      | 1024 CPU / 2048 MiB, 3 tasks    |
| CloudWatch log retention     | 7 days                        | 90 days                        |
| ECS Container Insights       | disabled                     | enabled                        |
| RDS instance class           | `db.t4g.micro`                | `db.r6g.large`                 |
| RDS storage                  | 20 GB (autoscale to 50)       | 100 GB (autoscale to 500)      |
| RDS Multi-AZ                 | false                         | true                           |
| RDS backup retention         | 1 day                         | 30 days                        |
| RDS deletion protection      | false                         | true                           |
| RDS skip final snapshot      | true                          | false (always snapshots)       |
| RDS Performance Insights     | false                         | true                           |
| VPC CIDR                     | `10.0.0.0/16`                 | `10.1.0.0/16`                  |

All of the above lives in each environment's `terraform.tfvars` and
`variables.tf` — the module code itself has no hardcoded environment
assumptions; every knob is a variable.

## Backend state

Each environment has its own `backend.tf` with an explicit S3 key and
DynamoDB lock table so a `dev` apply can never read or write `prod`
state:

```hcl
# envs/prod/backend.tf
terraform {
  backend "s3" {
    bucket         = "mycompany-terraform-state"
    key            = "myapp/prod/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "terraform-locks-prod"
    encrypt        = true
  }
}
```

Backend blocks can't reference variables, so the bucket/key/table are
hardcoded per environment file — update the bucket name to one you
control before running `init`. For stronger isolation, use a separate
AWS account per environment (and a separate backend bucket per
account) rather than just a separate state key in a shared account.

## Usage

```bash
cd envs/dev
terraform init
terraform plan   # picks up terraform.tfvars automatically
terraform apply

cd ../prod
terraform init
terraform plan
terraform apply
```

Because `terraform.tfvars` is auto-loaded by Terraform, you don't need
`-var-file` unless you add extra tfvars files (e.g. secrets pulled in
via CI). Each environment directory is fully self-contained — you can
`init`/`plan`/`apply` one without touching the other.

## Adding a third environment (e.g. staging)

1. Copy `envs/dev/` to `envs/staging/`.
2. Update `backend.tf` (new state key/lock table), `terraform.tfvars`
   (sizing, retention, deletion protection), and the VPC CIDR so it
   doesn't overlap dev/prod if you ever peer them.
3. No changes to `modules/` are needed — that's the point of keeping
   sizing and environment-specific settings entirely in variables.
