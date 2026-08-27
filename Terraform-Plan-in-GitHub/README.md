# .github/workflows/terraform-plan.yml — setup notes

This workflow runs `terraform fmt` → `init` → `validate` → `plan` on every
PR touching `infra/**`, once per environment (`dev`, `prod`), and posts
each environment's plan as a **sticky PR comment** (updated in place on
every push, not duplicated), plus uploads the full plan as a **workflow
artifact**, plus writes it to the **job summary**. No `apply` step exists
anywhere in the file — it's plan-only by design, matching "actual AWS
deployment is not required."

## Why it needs AWS access at all

`terraform plan` needs to read real AWS state to produce an accurate
diff (existing VPCs, whether the DB subnet group already exists, etc.),
even though it changes nothing. This workflow authenticates via
**OIDC** (no long-lived AWS access keys stored in GitHub) using
[`aws-actions/configure-aws-credentials`](https://github.com/aws-actions/configure-aws-credentials).

If you'd rather not wire up any AWS access at all yet, the workflow will
still run `fmt` and get partway through `init`/`validate`/`plan` — those
last two will fail without credentials, which is expected until the
setup below is done. `fmt-check` (job 1) needs no AWS access and works
immediately.

## One-time setup required

1. **Create two GitHub Environments** named `dev` and `prod`
   (Settings → Environments). The workflow's `plan` job sets
   `environment: ${{ matrix.environment }}`, so each environment can
   hold its own value for the same secret/variable names without any
   extra logic in the YAML:
   - Secret `AWS_ROLE_ARN` — the IAM role this environment's plan job assumes
   - Variable `AWS_REGION` — e.g. `ap-south-1`

   Optionally add environment protection rules (required reviewers) on
   `prod` if you want a human gate before its plan job even runs.

2. **Create a read-only IAM role per environment**, trusted for GitHub's
   OIDC provider, scoped to `Describe*` / `List*` / `Get*` on the
   services this stack touches (EC2/VPC, ECS, RDS, ELB, IAM, Secrets
   Manager, CloudWatch Logs, S3/DynamoDB for backend access). Do **not**
   grant `Create*`/`Update*`/`Delete*` — plan doesn't need them, and
   withholding them is what makes this genuinely safe to run on
   untrusted PR branches. AWS's own guide for the trust policy:
   <https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services>

3. **Backend prerequisites** — the S3 bucket and DynamoDB lock table
   referenced in `infra/envs/<env>/backend.tf` must already exist (see
   the earlier note on bootstrapping them); `terraform init` reads from
   them but doesn't create them.

## What each job does

| Job | Needs AWS? | Fails the PR if... |
|-----|-----------|---------------------|
| `fmt-check` | No | Any `.tf` file isn't `terraform fmt`-clean |
| `plan` (matrix: dev, prod) | Yes (OIDC, read-only) | `init`/`validate` error, or `plan` itself errors (not merely "has changes") |

`plan` is intentionally allowed to *have changes* without failing the
job — a plan showing resource changes is normal and expected on a PR.
Only a plan/validate **error** fails the check.

## Reading the output

- **PR comment**: one collapsible comment per environment, marked
  `<!-- terraform-plan-dev -->` / `<!-- terraform-plan-prod -->` so
  re-pushes update the same comment instead of spamming new ones.
- **Artifact**: `tfplan-dev` / `tfplan-prod`, retained 14 days — the
  full untruncated plan, useful when it's too long for the ~60KB
  comment cap (the comment step truncates and links here in that case).
- **Job summary**: same content, visible directly on the workflow run
  page under Checks, for anyone who doesn't open PR comments.
