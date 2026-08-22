# Roadmap — 3-Week Compressed Plan

Compressed from the original [8-week design doc](aws-attack-defense-roadmap.md) (`aws-attack-defense-roadmap.md`, kept for reference). Scope decision: **build all 3 scenarios, drop the dedicated Terraform Associate exam-prep track** — certification can be pursued separately later if desired.

Start date: **2026-08-21**. Target ship date: **2026-09-11** (3 weeks).

---

## Week 1 — Foundations + Scenario 1 (S3 Data Exfiltration)

- [x] Day 1 (2026-08-21): Environment setup — Terraform, AWS CLI v2, Ansible + boto3 (venv), git repo, GitHub repo, Claude memory, private project log. Terraform/Ansible core concepts (providers, resources, state, `plan`/`apply`/`destroy`; inventory, playbooks, idempotency). Scenario 1 Terraform skeleton: VPC, public subnet, EC2 app server, misconfigured public S3 bucket, CloudTrail.
- [x] Day 2-3: Scenario 1 end-to-end DONE: `terraform apply` → anonymous attack → CloudTrail data-event detection (raw log + jq) → `terraform destroy`. Cycle fits under 1h. Attack + detect scripted (`scripts/attack.sh`, `scripts/detect.sh`).
- [x] Day 4: manifest schema v1 finalized against the real deploy (verified detection query, caveats).
- [ ] Day 5: Wrap the manual attack into a script (`scripts/attack-s3-exfil.sh` or `.py`). Implement the 1-hour auto-teardown (EventBridge + Lambda, or scheduled `terraform destroy`).

## Week 2 — Scenario 2 (IAM Privilege Escalation) + Scenario 3 (EC2 Lateral Movement)

- [ ] Day 1-2: Scenario 2 — IAM roles with an AssumeRole escalation chain / overly-permissive policy. Ansible seeds initial low-priv credentials. Automated attack script + CloudTrail/STS detection. Reuse Week 1's teardown mechanism.
- [ ] Day 3: Refactor shared Terraform into modules (VPC, logging) now that 2 scenarios exist and the duplication is real, not hypothetical.
- [ ] Day 4-5: Scenario 3 — multi-subnet VPC, 2-3 instances, intentional security-group gaps enabling lateral movement. Detection via VPC Flow Logs → CloudWatch Logs Insights. Migrate state to an S3 + DynamoDB backend. Add `terraform validate` + `tflint` in GitHub Actions.

## Week 3 — Polish + Ship

- [ ] Day 1-2: Per-scenario READMEs with architecture diagrams (Mermaid), plus remediation notes (the "defense" write-up: what the fix would have been, not just how it was detected).
- [ ] Day 3: Short demo recording(s) — 2-3 min deploy → attack → detect → teardown, at least for Scenario 1. Root README polish.
- [ ] Day 4: Final zombie-resource sweep across all scenarios, cost review, tag `v1.0`.
- [ ] Day 5: LinkedIn launch post (see `log_project.md` for raw material). Buffer/slack day for anything that slipped.

---

## Deliverables Checklist

- [ ] 3 scenario packs (S3 exfil, IAM privesc, lateral movement)
- [ ] YAML manifest schema (with `ttl_minutes`)
- [ ] Automated attack scripts (full cycle < 1h)
- [ ] 1-hour auto-teardown mechanism
- [ ] Reusable Terraform modules (VPC, logging)
- [ ] S3 + DynamoDB state backend
- [ ] CI (validate + lint)
- [ ] Architecture diagrams + demo recording(s)
- ~~Terraform Associate certification~~ — dropped from scope to fit 3 weeks; revisit after ship if there's appetite

## Risk Mitigations

| Risk | Mitigation |
|---|---|
| Forgotten resources (main cost risk) | 1-hour auto-teardown + weekly zombie sweep + budget alerts at $5/$8/$10 |
| Tool learning overwhelm | Front-loaded into Week 1 Day 1 before building |
| Scope creep | Hard cap at 3 scenarios; no 4th even if ahead of schedule |
| Detection latency in 1h window | CloudTrail + Flow Logs, not GuardDuty |
| 3-week crunch (compressed from 8) | Exam-prep track dropped entirely; modules/backend/CI deferred to Week 2 once real duplication exists, not built speculatively |
