# prac-modules

Terraform code that provisions a small two-tier AWS network — VPC, public/private
subnets, security group, and EC2 instances running nginx — duplicated across two
independent environments, `development/` and `production/`. This README explains
what the infrastructure is, and separately, why and how it's now deployed through
GitHub Actions instead of by running `terraform apply` from a laptop.

## Part 1 — What the infrastructure is

### The modules

| Module | What it creates |
|---|---|
| `modules/network` | VPC, 3 public subnets, 3 private subnets, an Internet Gateway, route tables and associations |
| `modules/sg` | One security group allowing inbound 80/443/445/8080/22/3389 from anywhere, all egress |
| `modules/compute` | EC2 instances (public-facing and private) that bootstrap nginx via `user_data` and serve a sample page |

### The two root configurations

- **`development/`** — calls all three modules. VPC `10.90.0.0/16`, environment tag `Development`. Fully wired: network → security group → EC2.
- **`production/`** — calls `network` and `sg` only (VPC `192.168.0.0/16`, environment tag `Production`). No compute module is invoked yet, so production has no EC2 instances today.

Each root config has its own Terraform state, stored remotely in S3 (`s3://myansibles3bucketnasa`, keys `Development.tfstate` / `Production.tfstate`), so applying one environment never touches the other's state.

### Known quirks worth knowing about

- The instance count logic (`var.environment == "Prod" ? 3 : 1`) checks for the literal string `"Prod"`, but production sets `environment = "Production"` — so even once compute is wired up for prod, this condition won't match and it'll deploy 1 instance instead of 3.
- The "private" subnets still have a route to the Internet Gateway — there's no NAT gateway, so they're not truly network-isolated, they just don't get a public IP assigned to the instance itself.
- The security group is wide open (`0.0.0.0/0` on SSH/RDP/HTTP/HTTPS) — fine for a lab, not for anything handling real traffic or data.

## Part 2 — Why this is now automated with GitHub Actions

### The problem being solved

Originally, changes were applied by running `terraform plan` / `terraform apply` manually from a local machine. That works, but it means:
- Anyone with local AWS credentials can apply changes straight to real infrastructure, with no review step.
- There's no consistent, visible record of *what* was about to change before it changed.
- Mistakes (like the quoted-string outputs bug this repo hit, or unformatted files) only get caught by whoever happens to run the command.

The goal: **every change to the infrastructure should be visible as a `terraform plan` on a pull request before it's allowed to run**, and **applying that plan to real AWS resources requires an explicit, logged human approval** — separately for development and production.

### How the automation works

Three workflow files under `.github/workflows/`:

**`terraform.yml`** — the main pipeline
1. **`fmt`** — runs `terraform fmt -check -recursive` across the whole repo on every PR and push. Fails fast if formatting drifted (this is what caught the formatting issues found earlier).
2. **`plan`** — runs only on **pull requests**. For both `development` and `production` (as a matrix), it runs `terraform init`, `terraform validate`, and `terraform plan`, then posts the plan output as a comment on the PR. This is the "review step" — you see exactly what would change before anyone approves anything.
3. **`apply-development`** / **`apply-production`** — run only on a **push to the default branch** (i.e., when a PR is merged). Each is tied to a GitHub **Environment** (`development`, `production`) that has "required reviewers" turned on, so the job pauses and waits for a manual approval click before it actually runs `terraform apply`. Development and production are approved independently.

**`terraform-destroy.yml`** — a separate, manually-triggered workflow (`workflow_dispatch` only — it never fires on its own). You choose a target (`development`, `production`, or `both`) and must type the word `destroy` to proceed, then each destroy job still waits for the same environment approval before it runs `terraform destroy`. This exists so tearing down infrastructure is a deliberate, reviewable action, not an accident.

### Why OIDC instead of AWS access keys

Rather than storing long-lived `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` values as GitHub secrets (which are a standing liability if ever leaked), the workflows authenticate using **OpenID Connect (OIDC)**: GitHub issues a short-lived, cryptographically signed token for each workflow run, and AWS's IAM trusts that token — scoped specifically to this repo (`popoolaa/prac-modules`) — to grant temporary credentials. There is no AWS secret sitting in GitHub at rest at all.

This trust relationship is set up once via `bootstrap/github-oidc/` — a small, separate Terraform config (its own state file, `bootstrap-github-oidc.tfstate`) that creates:
- The GitHub OIDC identity provider in the AWS account (one per account).
- An IAM role (`github-actions-terraform`) that only GitHub Actions running as this repo — on a pull request, on `main`/`master`, or under the `development`/`production` GitHub Environments — is allowed to assume.
- Permissions on that role: EC2/VPC management (covers everything `network`, `sg`, and `compute` touch) plus read/write access to just the Terraform state bucket.

This bootstrap step is applied locally, once, with your own AWS credentials — it's the one piece of this system that has to exist before CI can do anything, so it can't bootstrap itself.

### Why a PR is required at all (branch protection)

Without branch protection, `git push origin main` and "a PR got merged into main" look **identical** to GitHub Actions — both are just a `push` event. So even with all the workflow logic above, someone could still push straight to `main` and trigger an apply with zero review. Branch protection (requiring a PR, requiring the `fmt`/`plan` checks to pass before merge) is what actually forces every change through the review pipeline — the workflow YAML alone can't enforce that.

### A note on `main` vs `master`

This repo has both a `main` and a `master` branch on GitHub, and **`main` is the actual configured default branch**. That matters for two reasons: GitHub only lists `workflow_dispatch`-triggered workflows (like `terraform-destroy.yml`) in the Actions UI once the workflow file exists on the default branch, and having two similarly-named long-lived branches invites confusion about which one is "real." Worth consolidating onto one branch going forward.

## Day-to-day usage, once set up

1. Make a change under `development/`, `production/`, or `modules/` on a feature branch.
2. Open a PR into the default branch — `fmt` and `plan` run automatically, and the plan is posted as a PR comment.
3. Review the plan, merge the PR.
4. Go to the Actions tab, find the run, and approve the `development`/`production` apply job(s) — this is where `terraform apply` actually executes against AWS.
5. To tear anything down, use the **Terraform Destroy** workflow from the Actions tab (manual trigger only), and approve it the same way.

Local `terraform plan`/`apply` still works exactly as before with your own AWS credentials — this automation is an additional, reviewed path to production, not a replacement for local usage.
