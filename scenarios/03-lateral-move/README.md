# Scenario 03 — EC2 Lateral Movement

**Status:** 📝 planned — not started. No Terraform yet; this is a placeholder so the
repo's scenario structure is visible ahead of Week 2. See [`manifest.yaml`](manifest.yaml)
for the (empty, TBD) scenario schema and [ROADMAP.md](../../ROADMAP.md) for the current plan.

## Planned objective

A multi-subnet VPC with 2-3 instances and an intentional security-group gap that
lets an attacker who compromises one instance pivot to another — detected via
VPC Flow Logs → CloudWatch Logs Insights instead of CloudTrail (this scenario is
what pulls Flow Logs into the kit).

Naming convention for when this is built: AWS resources use the
`lateral-move-*` prefix (already authorized in `iam/iac-user-policy.json`).
