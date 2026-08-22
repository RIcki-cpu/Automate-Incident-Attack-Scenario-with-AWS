# AWS Attack-Defense Scenario Kit

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
| 01 | S3 Data Exfiltration | 🚧 skeleton | Anonymous public-bucket read | CloudTrail S3 data events |
| 02 | IAM Privilege Escalation | ⏳ planned | AssumeRole escalation chain | CloudTrail IAM/STS events |
| 03 | EC2 Lateral Movement | ⏳ planned | Security-group gap pivot | VPC Flow Logs → Logs Insights |

See [`scenarios/01-s3-exfil/`](scenarios/01-s3-exfil/) for the first pack and its manifest.

## Repo layout

```
scenarios/
  01-s3-exfil/
    terraform/       # VPC, EC2, misconfigured S3 bucket, CloudTrail
    manifest.yaml     # scenario schema: objectives, attack path, detection, teardown
    README.md          # scenario-specific deploy/attack/detect/teardown walkthrough
.venv/                 # local Python env: ansible, boto3 (gitignored)
ROADMAP.md             # working 3-week plan (this is the live plan)
aws-attack-defense-roadmap.md  # original 8-week design doc, kept for reference
```

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform) >= 1.9
- [AWS CLI v2](https://docs.aws.amazon.com/cli/) with an authenticated IAM identity (`aws sts get-caller-identity` should return something)
- Python 3 + the project venv: `python3 -m venv .venv && .venv/bin/pip install ansible boto3`
- An AWS account you're comfortable deploying *intentionally misconfigured* (but disposable) resources into. **Recommend AWS Budget alerts at $5/$8/$10** before deploying anything (see Safety below).

## Quick start (Scenario 1)

```bash
cd scenarios/01-s3-exfil/terraform
cp terraform.tfvars.example terraform.tfvars   # set allowed_ssh_cidr to YOUR_IP/32
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
