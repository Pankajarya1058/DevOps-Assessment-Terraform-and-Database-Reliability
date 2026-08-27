# Internet → ALB → ECS/Fargate → RDS

Terraform for a 3-tier setup on AWS: public-facing ALB, Fargate tasks in
private subnets, and an RDS database that is reachable only from those
Fargate tasks.

## Layout

| File                 | Contents                                                      |
|----------------------|----------------------------------------------------------------|
| `versions.tf`        | Provider/Terraform version pins                                |
| `variables.tf`       | All configurable inputs (region, CIDRs, image, DB engine, etc.)|
| `vpc.tf`             | VPC, IGW, public/private-app/private-db subnets, NAT, routing   |
| `security_groups.tf` | ALB, ECS task, and RDS security groups                          |
| `alb.tf`             | ALB, target group, HTTP listener                                |
| `ecs_iam.tf`         | ECS execution/task IAM roles, CloudWatch log group              |
| `ecs.tf`             | ECS cluster, Fargate task definition, ECS service               |
| `rds.tf`             | DB subnet group, RDS instance, Secrets Manager credentials      |
| `outputs.tf`         | ALB DNS name, subnet IDs, RDS endpoint, secret ARN              |

## Network design

```
Internet
   │
   ▼
[ ALB ]  <- public subnets (2 AZs), sg: alb-sg (80/443 from 0.0.0.0/0)
   │
   ▼
[ ECS/Fargate tasks ]  <- private-app subnets (2 AZs), sg: ecs-tasks-sg
   │                       (container port, ONLY from alb-sg)
   ▼
[ RDS ]  <- private-db subnets (2 AZs), sg: rds-sg
             (db port, ONLY from ecs-tasks-sg — no CIDR ingress at all)
```

- **Public subnets** hold the ALB and the NAT Gateways only.
- **Private-app subnets** hold the Fargate tasks. They route outbound
  through NAT (needed to pull images and reach AWS APIs) but have no
  direct inbound path from the internet.
- **Private-db subnets** hold RDS and have no route to the internet or a
  NAT gateway at all — fully isolated except for intra-VPC traffic.
- RDS's security group only allows inbound traffic from the ECS tasks'
  security group (`security_groups = [aws_security_group.ecs_tasks.id]`),
  not from any CIDR block, and `publicly_accessible = false`. Even if
  someone were on the VPC, only resources wearing the `ecs-tasks-sg` can
  reach the DB port.

## Credentials

The RDS master password is generated with `random_password` and stored in
Secrets Manager (`aws_secretsmanager_secret.db_credentials`) as a JSON
blob (`host`, `port`, `dbname`, `username`, `password`). The ECS task
definition pulls each field in via the `secrets` block, so nothing
sensitive sits in the task definition or in your shell history — only in
Terraform state, which you should keep in an encrypted remote backend
(S3 + KMS, or Terraform Cloud) rather than local `.tfstate`.

## Usage

```bash
terraform init
terraform plan
terraform apply
```

Defaults to PostgreSQL and a placeholder Nginx image
(`public.ecr.aws/nginx/nginx:stable`) just to prove the path works.
Swap in your own image/repo via `container_image`, and adjust
`container_port` to match it.

Example overrides (`terraform.tfvars`):

```hcl
aws_region       = "ap-south-1"
project_name     = "myapp"
container_image  = "123456789012.dkr.ecr.ap-south-1.amazonaws.com/myapp:latest"
container_port   = 8080
db_engine        = "mysql"
db_engine_version = "8.0"
desired_count    = 2
```

After `apply`, hit `terraform output alb_dns_name` in a browser — traffic
flows ALB → target group → Fargate task. The task connects to RDS using
the `DB_HOST` / `DB_PORT` / `DB_USERNAME` / `DB_PASSWORD` env vars it
gets from Secrets Manager at launch.

## Notes / things to change for real production use

- `skip_final_snapshot = true` and `deletion_protection = false` on RDS
  are set for easy teardown in a demo — flip both before using this for
  anything real.
- The ALB listener is HTTP-only. Add an ACM certificate and an HTTPS
  listener (plus an HTTP→HTTPS redirect) for production traffic.
- `db_multi_az` defaults to `false` to keep cost down; set `true` for
  production HA.
- No bastion/Session Manager access to the private subnets is included
  here — add one (or use ECS Exec) if you need to shell into a running
  task or reach RDS directly for migrations/debugging.
