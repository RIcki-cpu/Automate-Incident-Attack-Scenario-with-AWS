# Scenario 02 — IAM Privilege Escalation

**Status:** 🚧 skeleton (Terraform written and ready to deploy; attack/detect steps below are pending the first real run — see [`manifest.yaml`](manifest.yaml) `status`)

## What this deploys

A low-privilege IAM user (`iam-privesc-analyst`) with a real access key and exactly one real permission — a scoped `sts:AssumeRole` grant — plus a second, more-privileged role (`iam-privesc-broad-read`) with broad (but lab-safe, read-only) S3/IAM permissions. No VPC, no EC2 instance: this scenario is purely identity-layer, unlike Scenario 1. See [`manifest.yaml`](manifest.yaml) for the full spec.

**Two independent misconfigurations, both required** (the same "two locks" shape as Scenario 1's disabled Block Public Access + public bucket policy):

1. The analyst user's identity policy grants `sts:AssumeRole` broadly (scoped to this scenario's role-name prefix, but nothing narrower).
2. The `broad-read` role's **trust policy** trusts this account's `:root` ARN — which counterintuitively means *any authenticated principal in the account*, not literally the root user. This is one of the most common real IAM findings; most cloud security scanners flag it specifically.

Neither alone is enough. The analyst's permission to *call* AssumeRole doesn't matter unless the target's trust policy also allows it in.

## Prerequisite: IAM policy update required

This scenario needs `iam:CreateUser`/`iam:CreateAccessKey`/etc., which `IaC_user` didn't have before (Scenario 1 only needed role-related actions). The updated policy — a new `ScenarioUsersOnly` statement, plus removal of the unused `athena:*`/`glue:*` grants — is already in [`iam/iac-user-policy.json`](../../iam/iac-user-policy.json). **This needs to be re-attached via the AWS Console by an admin identity** before `terraform apply` will work here — see [`iam/README.md`](../../iam/README.md).

## Deploy

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

No `terraform.tfvars` required — every variable has a default.

## Attack

Run `scripts/attack.sh`. It reads the analyst's credentials and the target role ARN from `terraform output` — nothing hardcoded, and the analyst's secret key is never written to a file or printed anywhere. It shows the full before/after: denied as the analyst, then a successful escalation via `sts:AssumeRole`, then proof of broader access using the assumed role's temporary credentials.

## Detect

Run `scripts/detect.sh` — it syncs this scenario's own CloudTrail logs and finds the `AssumeRole` call against the `broad-read` role, naming the caller. Unlike Scenario 1, this is a **management event** (on by default), not a data event requiring explicit activation — see `terraform/cloudtrail.tf` for that contrast. Because ordinary `AssumeRole` calls are common in any account, detection deliberately matches on both the caller identity *and* the specific target role, not the event name alone.

## Remediate

- Scope the `broad-read` role's trust policy to the specific principal(s) that actually need it — never trust the bare account `:root` ARN unless that's genuinely the intent.
- Scope the analyst's `sts:AssumeRole` grant to the exact role ARN(s) it needs, not a wildcard prefix.
- Turn on IAM Access Analyzer, which specifically flags roles trusting overly-broad principals including account root.

## Teardown

```bash
terraform destroy
```
