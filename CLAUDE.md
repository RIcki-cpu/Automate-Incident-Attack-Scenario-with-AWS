# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

An AWS security learning project: self-contained, disposable "scenario packs" (Terraform + Ansible) that each deploy an intentionally-misconfigured AWS environment, get attacked manually, get detected via CloudTrail/VPC Flow Logs, and tear down — targeting a 1-hour deploy→attack→detect→destroy cycle. Also a portfolio piece intended for a public GitHub repo and a LinkedIn write-up.

The user is learning Terraform/Ansible/AWS from scratch through this project. **Write more explanatory comments in this repo than you normally would** — `.tf`/`.yml` files here should explain what each resource/block does and why it exists in plain terms, not just non-obvious workarounds, so the user can self-diagnose if something breaks. Keep the same standard in per-scenario READMEs (objective, attack path, detection, remediation, teardown spelled out explicitly).

## Environment: this runs inside a Flatpak sandbox

This matters for every command you run here. `/etc/os-release` inside this shell reports "Freedesktop SDK" — the Bash tool's default view of `/usr`, `/bin`, etc. is the **Flatpak runtime's own filesystem**, not the host OS. Consequences:

- No `apt`/`snap`/`sudo` available by default. All project tooling installs to **user-space**: Terraform and AWS CLI v2 live in `~/.local/bin` (static binary / official installer with `-i`/`-b` pointing at `~/.local/aws-cli` + `~/.local/bin`).
- `$HOME` **is** shared/bind-mounted with the real host, so anything under `~/` — `~/.local/bin`, `~/.aws/`, `~/.config/gh/`, `~/.gitconfig`, and all project files under this repo — is the same file whether accessed from here or from the user's own terminal. No need to re-run `aws configure` / `git config` / etc. "in here" if it was already done in a regular terminal.
- System-package-manager installs (anything under host `/usr`) are **invisible by default** — e.g. the host has a system Ansible at `/usr/bin/ansible` (v2.16.3) that this sandbox cannot see unless you explicitly escape it.
- To run something against the real host directly (bypassing the sandbox's `/usr`), prefix with `flatpak-spawn --host <command>`. Use this only to check/diagnose host state — the project's own workflow should not depend on it (see next point).

**Ansible: two installs exist — always use the project's `.venv`, never bare `ansible`.** The host has a system Ansible (`/usr/bin/ansible`, 2.16.3) invisible to this sandbox; this project also has its own `.venv` (ansible-core 2.21.3 + boto3). Bare `ansible`/`ansible-playbook` inside this sandbox will resolve to **neither** unless the venv is active. Always use `.venv/bin/ansible-playbook` (or `source .venv/bin/activate` first) so what Claude runs and what the user runs manually stay identical.

## Commands

Terraform (run from the scenario's `terraform/` directory, e.g. `scenarios/01-s3-exfil/terraform/`):
```bash
terraform init
terraform fmt -recursive      # format
terraform validate            # syntax/type check — closest thing to a "test" right now
terraform plan                # preview changes — safe, read-only
terraform apply                # creates real, billable AWS resources
terraform destroy              # always run this when done with a scenario
```

Ansible (project-local venv — see warning above):
```bash
.venv/bin/ansible --version
.venv/bin/ansible-playbook <playbook>.yml -i <inventory>
```

AWS CLI (credentials already configured via `~/.aws/`):
```bash
aws sts get-caller-identity   # verify auth
aws configure list             # check configured profile/region, no secrets shown
```

There is no CI or lint step yet (`tflint` + GitHub Actions are planned for Week 2 per `ROADMAP.md`) — `terraform fmt`/`validate` are the only checks that currently exist.

## Architecture: scenario packs

Each scenario lives under `scenarios/NN-name/` and is self-contained:
- `terraform/` — the infrastructure, flat (no shared modules yet — modules are deliberately deferred until Week 2, once real duplication exists across 2+ scenarios, not built speculatively)
- `manifest.yaml` — the scenario schema: `objectives`, `attack_path`, `detection` (source/query), `remediation`, `teardown`, and a top-level `status` field used as a lightweight state machine (`planned -> skeleton -> deployed -> attacked -> detected -> torn_down` — `planned` covers a scenario directory that exists as a placeholder with no Terraform yet, e.g. scenarios 02/03). **Check `status` before assuming what's actually been done to a scenario** — it's the source of truth, more so than this file.
- `README.md` — deploy / attack / detect / remediate / teardown walkthrough for that specific scenario.

**Key pattern — the vulnerability is deliberately isolated.** In scenario 01, the EC2 instance's IAM role is intentionally least-privilege (scoped only to its own bucket) — the actual misconfiguration is the S3 bucket policy (public read, principal `*`) plus a disabled Block Public Access setting. The compute/app layer is kept reasonably well-configured on purpose so each scenario's detection query can target the *specific* named misconfiguration instead of "anything weird about this instance." Keep this separation when building scenarios 02/03.

**Cost/safety convention:** the AWS provider sets `default_tags` (`Project`, `Scenario`, `ManagedBy`, `TTLMinutes`) and every S3 bucket is `force_destroy = true`. This tagging + force-destroy pattern is the project's primary defense against forgotten/orphaned resources — carry it into every new scenario.

## AWS account constraints

Terraform authenticates as `IaC_user`, which is deliberately **not** an admin. Its permissions come from `iam/iac-user-policy.json` (see `iam/README.md`), scoped by resource-name prefix: S3 buckets and IAM roles/instance-profiles must be named `s3-exfil-*`, `iam-privesc-*`, or `lateral-move-*`. **New scenarios must follow one of those prefixes or `terraform apply` will fail with AccessDenied** — if a new scenario needs a different name or a new AWS service, `iam/iac-user-policy.json` has to be updated and re-attached by an admin identity first.

An explicit `Deny` prevents this user from modifying its own IAM identity, so it can never grant itself the missing permission — that always requires the account admin, which is the user's manual step, not something to attempt via the CLI.

Scenario 01 also depends on **account-level Block Public Access being off**. If it's on, AWS silently rejects the public bucket policy and the scenario deploys but isn't actually vulnerable — the attack step then fails with a 403 that looks like a bug in the attack rather than a config problem. Check with `aws s3control get-public-access-block --account-id <ID>` before debugging anything else.

## Roadmap documents — which one is authoritative

- `ROADMAP.md` — the **live** 3-week plan. Scope was deliberately compressed from 8 weeks to 3: all 3 scenarios are still in scope, but the dedicated Terraform-certification exam-prep track was dropped entirely. Check this file for current phase/status.
- `aws-attack-defense-roadmap.md` — the **original** 8-week design doc. Historical reference only; not actively followed. Don't reconcile discrepancies in its favor.
- `log_project.md` — **private**, gitignored working log (decisions, blockers, timings) kept as raw material for an eventual LinkedIn post. Useful for "why was this decided" context, but not a source of architecture truth.

## Current status

Scenario 01 (S3 Data Exfiltration): **complete** — deployed, attacked (anonymous `GetObject`/`ListObjects`), detected (CloudTrail S3 data events, parsed via `scripts/detect.sh`), and torn down clean (zombie sweep verified). See `docs/technical-design.md` for the verified findings (a data-event activation-gap window right after `terraform apply`; anonymous `aws s3 ls` logs as `ListObjects`, not `ListBucket`). The instance has no SSH access or key pair by design (the attack is anonymous S3 access from the operator's own machine, and never touches the EC2 instance at all — the VPC/EC2 exist for narrative realism and the least-privilege contrast, not because the attack needs them); port 22 returns in Week 2 when Ansible needs it. Scenario 02 (IAM Privilege Escalation): Terraform written and `validate`-clean (`status: skeleton`) — two independent misconfigurations (analyst user's broad `sts:AssumeRole` grant + `broad_read` role's trust policy trusting account `:root`), deliberately no VPC/EC2 (identity-layer only, leaner than Scenario 01 on purpose). Blocked on the updated `iam/` policy (new `ScenarioUsersOnly` statement, needed for `iam:CreateUser`/`CreateAccessKey`) being attached — same manual admin-Console step Scenario 01 needed. Scenario 03 (EC2 lateral movement): placeholder directory only (`manifest.yaml` + `README.md`, `status: planned`), no Terraform yet. Always confirm against each scenario's `manifest.yaml` `status` field rather than assuming.
