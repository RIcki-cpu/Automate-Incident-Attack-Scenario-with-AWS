# Roadmap — 3-Week Compressed Plan

Compressed from the original [8-week design doc](aws-attack-defense-roadmap.md) (`aws-attack-defense-roadmap.md`, kept for reference). Scope decision: **build all 3 scenarios, drop the dedicated Terraform Associate exam-prep track** — certification can be pursued separately later if desired.

Start date: **2026-08-21**. Target ship date: **2026-09-11** (3 weeks).

---

## Week 1 — Foundations + Scenario 1 (S3 Data Exfiltration)

- [x] Day 1 (2026-08-21): Environment setup — Terraform, AWS CLI v2, Ansible + boto3 (venv), git repo, GitHub repo, Claude memory, private project log. Terraform/Ansible core concepts (providers, resources, state, `plan`/`apply`/`destroy`; inventory, playbooks, idempotency). Scenario 1 Terraform skeleton: VPC, public subnet, EC2 app server, misconfigured public S3 bucket, CloudTrail.
- [x] Day 2-3: Scenario 1 end-to-end DONE: `terraform apply` → anonymous attack → CloudTrail data-event detection (raw log + jq) → `terraform destroy`. Cycle fits under 1h. Attack + detect scripted (`scripts/attack.sh`, `scripts/detect.sh`).
- [x] Day 4: manifest schema v1 finalized against the real deploy (verified detection query, caveats).
- [x] Day 5 (deferred by design): attack scripting is done (`scripts/attack.sh`/`detect.sh`). The auto-teardown mechanism (EventBridge+Lambda vs. scheduled destroy) was considered and consciously deferred — manual `terraform destroy` + zombie sweep already proven reliable on Scenario 1. Revisit alongside Week 2's GitHub Actions work if it becomes worth the IAM Console round-trip a Lambda-based version would need.

## Week 2 — Scenario 2 (IAM Privilege Escalation) + Scenario 3 (EC2 Lateral Movement)

- [x] Day 1-2: Scenario 2 DONE end-to-end — IAM privesc via blanket `sts:AssumeRole` + a role trusting account `:root`; attack + CloudTrail AssumeRole detection verified, torn down clean. (No Ansible — Scenario 2 is pure identity-layer; Ansible arrives in Scenario 3.)
- [ ] Day 3 (still pending): refactor shared Terraform into modules (VPC, logging) now that real duplication exists across scenarios — deferred alongside the state-backend/CI work below.
- [x] Day 4-5: Scenario 3 DONE end-to-end — two-tier VPC (public web host + private internal host), security-group gap (internal SG allows SSH from the web SG), Ansible configures the web host (first use of Ansible; the internal host self-configures via user_data so the A→B:22 flow is unambiguously the attack), attack.sh does the A→B pivot, detect.sh queries VPC Flow Logs via CloudWatch Logs Insights. Deployed, attacked, detected (verified: web host was the only source reaching B on 22), torn down clean.
- [ ] STILL PENDING (Week 2 leftovers, deliberately deferred to keep scenario momentum): migrate state to an S3 + DynamoDB backend; add `terraform validate` + `tflint` in GitHub Actions CI.

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
