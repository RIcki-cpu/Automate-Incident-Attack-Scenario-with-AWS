# Scenario 02 — IAM Privilege Escalation

**Status:** 📝 planned — not started. No Terraform yet; this is a placeholder so the
repo's scenario structure is visible ahead of Week 2. See [`manifest.yaml`](manifest.yaml)
for the (empty, TBD) scenario schema and [ROADMAP.md](../../ROADMAP.md) for the current plan.

## Planned objective

An IAM role with an over-permissive policy or an unconditioned `AssumeRole` /
`PassRole` chain that lets a low-privilege identity escalate to broader access —
then detect the escalation via CloudTrail IAM/STS events. Deliberately the mirror
image of the deploy-user hardening discussed in
[`../../iam/README.md`](../../iam/README.md) (permission boundary vs. explicit
`Deny`): this scenario is where that theory becomes something you can actually
attack.

Naming convention for when this is built: AWS resources use the
`iam-privesc-*` prefix (already authorized in `iam/iac-user-policy.json`).
