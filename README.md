# AWS Attack-Defense Scenario Kit

<p align="center">
  <img src="docs/architecture-diagram.png" alt="Architecture diagram of Scenario 01: an anonymous internet attacker reaches a misconfigured public S3 bucket directly over HTTPS, bypassing the VPC and EC2 app server entirely, while CloudTrail logs S3 data events for detection" width="850">
</p>

<p align="center"><em>Scenario 01 in one picture: the attack (red) never touches the VPC or EC2 instance — it goes straight for a misconfigured S3 bucket policy.</em></p>

Self-contained, disposable AWS "scenario packs" for practicing offensive techniques *and* writing the detection logic that catches them. Each scenario deploys with Terraform (+ Ansible where app config is needed), gets attacked, gets detected via CloudTrail / VPC Flow Logs, and tears itself down — designed to fit inside a 1-hour cost window.

Built as a hands-on Terraform learning project and a security portfolio piece: deploy → attack → detect → remediate → destroy, for each scenario.

## Why this exists

Most "cloud security" learning is either pure theory (read the whitepaper) or pure CTF (exploit a pre-built box someone else configured). This kit closes the loop: you write the vulnerable infrastructure yourself in Terraform, you attack it, and then you write the detection query that would have caught you — so the offense and defense sides reinforce each other.

## The 1-hour cycle

| Phase | Time | Tool |
|---|---|---|
| Deploy | 5-10 min | `terraform apply` (+ Ansible where noted) |
| Attack | 2-5 min | attack script (bash/python) |
| Detect | 5-15 min | CloudTrail data events / VPC Flow Logs → Athena / Logs Insights |
| Review + teardown | 5 min | detection query + `terraform destroy` |

**Why not GuardDuty for detection?** CloudTrail has ~5-15 min delivery latency; GuardDuty is slower (15+ min to hours). Detection here is built on CloudTrail + Flow Logs so it actually fits the 1-hour window. GuardDuty is treated as optional/out-of-band.

## Scenarios

| # | Name | Status | Attack | Detection |
|---|---|---|---|---|
| 01 | [S3 Data Exfiltration](scenarios/01-s3-exfil/) | ✅ verified end-to-end | Anonymous public-bucket read | CloudTrail S3 data events |
| 02 | [IAM Privilege Escalation](scenarios/02-iam-privesc/) | 🚧 skeleton | AssumeRole via overly-broad trust policy | CloudTrail AssumeRole event |
| 03 | [EC2 Lateral Movement](scenarios/03-lateral-move/) | 📝 planned | Security-group gap pivot | VPC Flow Logs → Logs Insights |

Scenario 01 has run its full deploy → attack → detect → destroy cycle against real AWS infrastructure — see [`scenarios/01-s3-exfil/`](scenarios/01-s3-exfil/) for the walkthrough and [`docs/technical-design.md`](docs/technical-design.md) for the full technical writeup (vulnerability mechanics, verified findings, and the design tradeoffs behind it).

## Repo layout

```
docs/                  # architecture diagram + docs/technical-design.md (the deep "why")
iam/                   # scoped IAM policy for the Terraform deploy user
scenarios/
  01-s3-exfil/          # complete: terraform/, manifest.yaml, scripts/{attack,detect}.sh, README.md
  02-iam-privesc/        # placeholder — Week 2
  03-lateral-move/       # placeholder — Week 2
.venv/                 # local Python env: ansible, boto3 (gitignored)
ROADMAP.md             # working 3-week plan (this is the live plan)
aws-attack-defense-roadmap.md  # original 8-week design doc, kept for reference
```

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform) >= 1.9
- [AWS CLI v2](https://docs.aws.amazon.com/cli/) with an authenticated IAM identity (`aws sts get-caller-identity` should return something)
- Python 3 + the project venv: `python3 -m venv .venv && .venv/bin/pip install ansible boto3`
- An AWS account you're comfortable deploying *intentionally misconfigured* (but disposable) resources into. **Recommend AWS Budget alerts at $5/$8/$10** before deploying anything (see Safety below).
- An IAM user for Terraform with the scoped policy in [`iam/`](iam/) attached — see [`iam/README.md`](iam/README.md) for setup and for the account-level Block Public Access check Scenario 01 depends on.

## Quick start (Scenario 1)

```bash
cd scenarios/01-s3-exfil/terraform
terraform init
terraform plan
terraform apply

# ... attack + detection steps: see scenarios/01-s3-exfil/README.md ...

terraform destroy   # always tear down when you're done
```

## Safety & cost controls

- Every scenario is tagged (`Project`, `Scenario`, `TTLMinutes`) and `force_destroy`'d so `terraform destroy` always fully cleans up.
- The S3 buckets in these scenarios are **intentionally public/misconfigured by design** — never put real data in them, and never leave one deployed longer than the scenario needs.
- Set up AWS Budget alerts before your first `apply`. A forgotten `t3.micro` is cheap (~$7.50/mo) but a forgotten public bucket is a real risk if it ever holds anything other than decoy data.
- A 1-hour auto-teardown mechanism (EventBridge + Lambda, or scheduled `terraform destroy`) is planned per scenario — see [ROADMAP.md](ROADMAP.md).

## Roadmap

[ROADMAP.md](ROADMAP.md) is the live 3-week plan this project is currently executing against. [aws-attack-defense-roadmap.md](aws-attack-defense-roadmap.md) is the original 8-week design doc it was compressed from — kept for reference, not actively followed.

## License

MIT — see [LICENSE](LICENSE).
