# AWS Attack-Defense Scenario Kit

<p align="center">
  <img src="docs/scenario-01-architecture.png" alt="Architecture diagram of Scenario 01: an anonymous internet attacker reaches a misconfigured public S3 bucket directly over HTTPS, bypassing the VPC and EC2 app server entirely, while CloudTrail logs S3 data events for detection" width="850">
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
| 02 | [IAM Privilege Escalation](scenarios/02-iam-privesc/) | ✅ verified end-to-end | AssumeRole via overly-broad trust policy | CloudTrail AssumeRole event |
| 03 | [EC2 Lateral Movement](scenarios/03-lateral-move/) | ✅ verified end-to-end | Security-group gap pivot (SSH A→B) | VPC Flow Logs → Logs Insights |

All three scenarios have run their full deploy → attack → detect → destroy cycle against real AWS infrastructure — see each scenario directory for its walkthrough and [`docs/technical-design.md`](docs/technical-design.md) for the full technical writeup (vulnerability mechanics, verified findings, and the design tradeoffs behind each).

<p align="center">
  <img src="docs/scenario-02-architecture.png" alt="Architecture diagram of Scenario 02: a low-privilege IAM analyst user is denied direct S3 access, but assumes an over-permissive role (its trust policy trusts the account root) to gain broader access, while CloudTrail logs the AssumeRole event for detection" width="720">
</p>

<p align="center"><em>Scenario 02: the analyst can't read S3 directly, so it escalates through a role that trusts too broadly — CloudTrail catches the <code>AssumeRole</code>.</em></p>

<p align="center">
  <img src="docs/scenario-03-architecture.png" alt="Architecture diagram of Scenario 03: an attacker gets access to a public web host, finds an SSH key, uses it to reach a private internal host through a security-group gap, and steals decoy database credentials, while VPC Flow Logs record the lateral movement" width="720">
</p>

<p align="center"><em>Scenario 03: the attacker lands on the public web host, finds an SSH key, and pivots to the private host through a security-group gap — VPC Flow Logs catch the web→internal SSH.</em></p>

## Repo layout

```
docs/                  # architecture diagrams + technical-design.md (the deep "why") + remote-state.md
iam/                   # scoped IAM policy for the Terraform deploy user
scripts/               # cross-scenario helpers (e.g. remote-state.sh)
state-backend/         # optional one-time bootstrap for S3 remote Terraform state
scenarios/
  01-s3-exfil/          # complete: terraform/, manifest.yaml, scripts/{attack,detect}.sh, README.md
  02-iam-privesc/        # complete: same layout, identity-layer (no VPC/EC2)
  03-lateral-move/       # complete: two-tier VPC, Ansible + user_data, Flow Logs detection
.venv/                 # local Python env: ansible, boto3 (gitignored)
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
- A 1-hour auto-teardown mechanism (EventBridge + Lambda, or scheduled `terraform destroy`) is a planned enhancement; for now, always run `terraform destroy` when you're done.

## Optional: remote Terraform state

Scenarios use **local** state by default (clone and go). If you'd rather keep state in a versioned, encrypted, private **S3 bucket** — with S3-native locking, so **no DynamoDB table** — it's an opt-in, Terraform-created setup: see [`docs/remote-state.md`](docs/remote-state.md).

## What's next

All three scenarios are complete and verified end-to-end. [docs/future-work.md](docs/future-work.md) sketches a larger multi-stage "full-chain compromise" idea deliberately kept out of this kit's scope.

## License

MIT — see [LICENSE](LICENSE).
