# Scenario 01 — S3 Data Exfiltration

**Status:** 🚧 skeleton (Terraform deploys; attack/detection steps below are TODO for Week 1 Day 2-3)

## What this deploys

A VPC with a public subnet, an EC2 "app server" with a tightly-scoped IAM role, and an S3 bucket whose Block Public Access is deliberately disabled with a public-read bucket policy attached — the actual vulnerability. A CloudTrail trail captures S3 data events (object-level `GetObject`/`ListObjects`) on that bucket so the anonymous access shows up in logs. See [`manifest.yaml`](manifest.yaml) for the full scenario spec.

**The EC2 instance and its IAM role are not the vulnerability** — only the bucket policy is. This mirrors a realistic root cause: someone disables Block Public Access to unblock a policy change and never scopes the policy back down.

## Deploy

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # set allowed_ssh_cidr to YOUR_IP/32
terraform init
terraform plan
terraform apply
```

Note the `data_bucket_public_url_example` output — that's the attack target.

## Attack (manual — TODO Week 1 Day 2-3)

Planned: an unauthenticated `curl` against the public object URL, then an anonymous `aws s3 ls --no-sign-request` against the bucket, with no AWS credentials involved on the attacker side. Will be scripted into `scripts/attack-s3-exfil.sh` once verified manually.

## Detect (TODO Week 1 Day 2-3)

Planned: query CloudTrail S3 data events (via Athena over the trail's S3 logs, or CloudTrail Lake) filtering for `GetObject`/`ListObjects` events on this bucket where the requester is unauthenticated/anonymous. The finalized query will replace the `TODO` in `manifest.yaml`.

## Remediate

- Re-enable S3 Block Public Access on the bucket (and ideally at the account level).
- Remove the wildcard-principal (`"AWS": "*"`) statement from the bucket policy.
- If public hosting is genuinely required, front the bucket with CloudFront + Origin Access Control instead of a public bucket policy.

## Teardown

```bash
terraform destroy
```

Every resource here is tagged (`Project`, `Scenario`, `TTLMinutes`) and the buckets are `force_destroy = true`, so destroy always fully cleans up — including the decoy object. Don't leave this deployed longer than the scenario needs.
