# AWS Attack-Defense Scenario Kit — 8-Week Roadmap (v2)

Description

Build 3–5 self-contained "scenario packs" — each a small AWS environment (VPC, EC2, IAM, S3) deployed with Terraform and configured with Ansible (vulnerable app, misconfigured permissions, exposed bucket, etc.). Each pack has a YAML manifest describing the attack path, detection rules, and expected evidence. You practice offensive techniques, then write detection logic (CloudTrail queries, GuardDuty custom rules)


## The 1-Hour Automated Cycle (design)

Target: a full learn/demo cycle fits inside a 1-hour auto-teardown window.

| Phase | Time | Tool |
|---|---|---|
| Deploy | 5-10 min | `terraform apply` + Ansible |
| Attack | 2-5 min | attack script (bash/python) |
| Detect | 5-15 min | CloudTrail data events + VPC Flow Logs -> Athena / Logs Insights |
| Review + teardown | 5 min | queries + `terraform destroy` |

**Key constraint:** CloudTrail has ~5-15 min delivery latency; GuardDuty is slower (15+ min to hours). So detection is built on CloudTrail + Flow Logs, NOT GuardDuty, for the fast cycle. Treat GuardDuty as optional/out-of-band.

**Auto-teardown:** an EventBridge rule + Lambda (or a scheduled `terraform destroy` via a local cron / CI job) kills the environment at T+60min regardless. This is your primary cost control — a forgotten `t3.micro` costs ~$7.50/month.

**Learning vs automation:** run each attack step manually the first time to understand it, THEN wrap it in the script. The script is both a time-saver and a portfolio artifact.

---

## Phase 0: Foundations (Week 0-1)

**Goal:** understand Terraform + Ansible well enough to build without fighting syntax.

### Week 0 (light, ~4-6h) — Terraform basics
- HashiCorp "Get Started - AWS" tutorial track end to end
- Concepts: providers, resources, variables, outputs, state, `plan`/`apply`/`destroy`
- Deploy + destroy a single EC2 instance from scratch, no copy-paste
- **Exam alignment:** IaC concepts, CLI workflow, providers

### Week 1 — Ansible basics + Scenario 1 scaffold
- Jeff Geerling intro: inventory, playbooks, roles, idempotency
- Configure that EC2 instance with a simple Ansible playbook
- Start **Scenario 1: S3 Bucket Misconfiguration** (Terraform: VPC, public subnet, EC2, over-permissive S3 bucket, CloudTrail)
- **Exam alignment:** resources, dependencies, state basics

---

## Phase 1: First Full Scenario (Week 2-3)

### Week 2 — Scenario 1 end-to-end + manifest
- Finish Scenario 1: deploy -> manual attack (S3 exfil) -> CloudTrail/Athena detection -> destroy
- Design the YAML scenario manifest schema v1:
  ```yaml
  scenario:
    name: "S3 Data Exfiltration"
    difficulty: beginner
    ttl_minutes: 60
    objectives: [...]
    attack_path: [...]
    detection: {source: cloudtrail, query: "..."}
    teardown: terraform destroy
  ```
- **Exam alignment:** variables, outputs, resource graph

### Week 3 — Automate Scenario 1 + auto-teardown
- Wrap the manual steps into an attack script; confirm the full cycle runs < 1h
- Implement the 1-hour auto-teardown (EventBridge + Lambda, or scheduled destroy)
- Add a `Makefile`: `make deploy SCENARIO=s3-exfil` / `make teardown`
- **Exam alignment:** modules (refactor common bits), lifecycle

---

## Phase 2: Depth (Week 4-5)

### Week 4 — Scenario 2: IAM Privilege Escalation
- Terraform: IAM roles with an AssumeRole escalation chain / wildcard policy
- Ansible: seed credentials + scenario state
- Automated attack + CloudTrail detection; reuse teardown
- Refactor shared Terraform into **modules** (VPC, logging)
- **Exam alignment:** modules (input/output/versioning), IAM as code

### Week 5 — Scenario 3: EC2 Lateral Movement + state backend
- Terraform: multi-subnet VPC, 2-3 instances, intentional security-group gaps
- Detection: VPC Flow Logs -> CloudWatch Logs Insights
- Migrate state to **S3 backend + DynamoDB locking** (real exam topic + good practice)
- Add `terraform validate` + `tflint` in GitHub Actions
- **Exam alignment:** backends, state management, workspaces, CI

---

## Phase 3: Polish + Exam (Week 6-8)

### Week 6 — Documentation + portfolio
- README with architecture diagram (Mermaid/draw.io)
- Short 2-3 min demo recording (deploy -> attack -> detect -> teardown)
- Remediation notes per scenario (the "defense" half)

### Week 7 — Terraform exam gap study
- Topics the project didn't cover deeply: Terraform Cloud / HCP, Sentinel, `import`, `taint`/`moved`, licensing/editions
- Practice exams (Bryan Krausen / official HashiCorp practice)

### Week 8 — Exam + ship
- Sit Terraform Associate early in the week
- Tag v1.0, publish launch post (see LinkedIn doc)

---

## Deliverables Checklist
- [ ] 3 scenario packs (S3 exfil, IAM privesc, lateral movement)
- [ ] YAML manifest schema (with `ttl_minutes`)
- [ ] Automated attack scripts (full cycle < 1h)
- [ ] 1-hour auto-teardown mechanism
- [ ] Reusable Terraform modules (VPC, logging)
- [ ] S3 + DynamoDB state backend
- [ ] CI (validate + lint)
- [ ] Architecture diagram + demo recording
- [ ] Terraform Associate certification

## Risk Mitigations
| Risk | Mitigation |
|---|---|
| Forgotten resources (main cost risk) | 1-hour auto-teardown + weekly zombie sweep + budget alert at $5/$8/$10 |
| Tool learning overwhelm | Front-loaded foundations Week 0-1 before building |
| Scope creep | Hard cap 3 scenarios; 4th only if ahead |
| Detection latency in 1h window | Use CloudTrail + Flow Logs, not GuardDuty |
| Part-time time crunch | Weeks 0-5 are the core; 6-8 can compress |
