# Scenario 01 — S3 Data Exfiltration

**Status:** ✅ verified end-to-end (deployed, attacked, detected, torn down clean — see [`manifest.yaml`](manifest.yaml) `status`)

## What this deploys

A VPC with a public subnet, an EC2 "app server" with a tightly-scoped IAM role, and an S3 bucket whose Block Public Access is deliberately disabled with a public-read bucket policy attached — the actual vulnerability. A CloudTrail trail captures S3 data events (object-level `GetObject`/`ListObjects`) on that bucket so the anonymous access shows up in logs. See [`manifest.yaml`](manifest.yaml) for the full scenario spec.

**The EC2 instance and its IAM role are not the vulnerability** — only the bucket policy is. This mirrors a realistic root cause: someone disables Block Public Access to unblock a policy change and never scopes the policy back down.

## Deploy

Prerequisite: the deploying IAM user needs the policy in [`iam/`](../../iam/)
attached, and account-level Block Public Access must be off — otherwise AWS
rejects the public bucket policy and the bucket won't actually be vulnerable.

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

No `terraform.tfvars` is required — every variable has a default. Copy
`terraform.tfvars.example` if you want to override the region. There is no SSH
access to the instance by design (see `security_group.tf`).

Note the `data_bucket_public_url_example` output — that's the attack target.

## Attack

Run `scripts/attack.sh`. It reads the target from `terraform output` and proves
exfiltration two ways, both with **no AWS credentials**:

1. `aws s3 ls s3://<bucket>/ --recursive --no-sign-request` — anonymous listing.
2. `curl <public object URL>` — unauthenticated HTTPS GET of the decoy CSV.

Both succeed (HTTP 200, file downloaded) against an internet-public bucket.

## Detect

Run `scripts/detect.sh` — it syncs the CloudTrail S3 data-event logs and finds the
anonymous access. The signal is **`userIdentity.accountId == "anonymous"`** (the
caller has no identity), matched against `GetObject`/`ListObjects` on this bucket.

Three things that matter here, proven while building this (see
[`docs/technical-design.md`](../../docs/technical-design.md) for detail):

- **Wait a few minutes after `terraform apply` before attacking.** S3 data-event
  logging is not retroactive and takes a few minutes to arm on a new trail — an
  attack fired immediately after apply is invisible and looks like a clean run.
- After attacking, CloudTrail delivery lags **~5-15 min** before the event is
  queryable.
- The anonymous `aws s3 ls` shows up as event name **`ListObjects`**, not
  `ListBucket`.

## Remediate

- Re-enable S3 Block Public Access on the bucket (and ideally at the account level).
- Remove the wildcard-principal (`"AWS": "*"`) statement from the bucket policy.
- If public hosting is genuinely required, front the bucket with CloudFront + Origin Access Control instead of a public bucket policy.

## Teardown

```bash
terraform destroy
```

Every resource here is tagged (`Project`, `Scenario`, `TTLMinutes`) and the buckets are `force_destroy = true`, so destroy always fully cleans up — including the decoy object. Don't leave this deployed longer than the scenario needs.
