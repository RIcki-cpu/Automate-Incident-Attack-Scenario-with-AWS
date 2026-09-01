# Scenario 02 — IAM Privilege Escalation

**Status:** ✅ verified end-to-end (deployed, attacked, detected, torn down clean — see [`manifest.yaml`](manifest.yaml) `status`)

## What this deploys

A low-privilege IAM user (`iam-privesc-analyst`) with a real access key, a blanket `sts:AssumeRole` grant, and read-only IAM enumeration — plus a second, more-privileged role (`iam-privesc-broad-read`) with broad (but lab-safe, read-only) S3/IAM permissions. No VPC, no EC2 instance: this scenario is purely identity-layer, unlike Scenario 1. See [`manifest.yaml`](manifest.yaml) for the full spec.

**Two independent misconfigurations, both required** (the same "two locks" shape as Scenario 1's disabled Block Public Access + public bucket policy):

1. The analyst user's identity policy grants `sts:AssumeRole` on `*` (any role) — the realistic blanket convenience grant. It also has read-only IAM enumeration, which is what lets the attacker discover the target role rather than being handed it.
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

Run `scripts/attack.sh`. It reads the analyst's credentials from `terraform output` (never written to a file or printed), then walks the full chain: confirm the low-priv identity → **recon** (the analyst lists roles and reads the target's trust policy, *discovering* it rather than being handed it) → prove no data access (denied) → escalate via `sts:AssumeRole` → prove broader access with the assumed role's temporary credentials. The same `list-buckets` call that's denied before the escalation succeeds after it — that before/after is the proof.

## Detect

Run `scripts/detect.sh` — it syncs this scenario's own CloudTrail logs and finds the `AssumeRole` call against the `broad-read` role, naming the caller. Unlike Scenario 1, this is a **management event** (on by default), not a data event requiring explicit activation — see `terraform/cloudtrail.tf` for that contrast. Because ordinary `AssumeRole` calls are common in any account, detection deliberately matches on both the caller identity *and* the specific target role, not the event name alone.

**Verified:** the attack logged one clean `AssumeRole` event (caller `iam-privesc-analyst`, target `iam-privesc-broad-read`), detected ~4.5 min after running — and, unlike Scenario 1's S3 data events, with **no activation gap** (management-event logging is always on). Teardown also surfaced a real gap: deleting an IAM user needs `iam:ListGroupsForUser` (the Terraform provider clears group memberships unconditionally), now added to the deploy policy — see [`docs/technical-design.md`](../../docs/technical-design.md).

## Remediate

- Scope the `broad-read` role's trust policy to the specific principal(s) that actually need it — never trust the bare account `:root` ARN unless that's genuinely the intent.
- Scope the analyst's `sts:AssumeRole` grant to the exact role ARN(s) it needs, not a wildcard prefix.
- Turn on IAM Access Analyzer, which specifically flags roles trusting overly-broad principals including account root.

## Teardown

```bash
terraform destroy
```
