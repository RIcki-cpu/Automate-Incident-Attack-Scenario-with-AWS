# Technical Design & Scenario Reference

The engineering companion to this kit: for each scenario, the vulnerability
mechanics, the attack automation workflow, the detection logic, remediation, and
the rationale behind the decisions that shaped it. Where a choice had a
defensible alternative, that alternative is named rather than hidden — the point
of the project is being able to justify every decision, not just ship something
that deploys.

- **Audience:** technical reviewers, and future-me. Assumes AWS/Terraform
  literacy; explains the security reasoning in full.
- **Relationship to other docs:** each scenario's `README.md` is the quick
  operational walkthrough; `manifest.yaml` is the machine-readable spec; this
  document is the deep "why." The private `log_project.md` is raw narrative
  source material and is not published.

---

## Cross-cutting design decisions

These apply to every scenario in the kit.

### The vulnerability is deliberately isolated

Each scenario keeps **exactly one thing** misconfigured and holds everything
around it to a reasonable standard. In Scenario 01 the EC2 instance's IAM role
is genuinely least-privilege (scoped to a single bucket ARN, not `s3:*`), so the
one thing wrong is the bucket policy and nothing else. This is a teaching choice:
a detection query can then target the *specific* misconfiguration instead of
drowning in noise from an environment that's insecure in ten different ways, and
a reader can point at one resource and say "that is the bug."

### Detection uses CloudTrail + VPC Flow Logs, not GuardDuty

GuardDuty is the obvious "AWS threat detection" answer, and it's deliberately
*not* the primary tool here. Its findings can lag 15 minutes to hours, which
does not fit a 1-hour deploy→attack→detect→destroy cycle. CloudTrail data events
(~5-15 min delivery) and VPC Flow Logs are slower than ideal but fast enough, and
crucially they make the detection *logic* explicit and reviewable — you write the
query, so you can defend it. GuardDuty is treated as optional/out-of-band.

### The deploy user is not an administrator

Terraform authenticates as `IaC_user`, whose permissions come from
`iam/iac-user-policy.json` — a least-privilege policy, not `AdministratorAccess`.

**Decision — scoped policy over admin.** Attaching `AdministratorAccess` would
have been faster and never needed iteration. It was rejected because
over-permissioned IAM is one of the exact misconfigurations this kit teaches
people to detect (it is essentially the subject of Scenario 02); a public
security portfolio whose own deploy user runs as root would undercut its own
argument. The policy scopes S3 and IAM by resource-name prefix
(`s3-exfil-*`, `iam-privesc-*`, `lateral-move-*`), enumerates EC2 actions rather
than granting `ec2:*`, and constrains `iam:PassRole` to the EC2 service.

**Decision — inline `Deny` vs. a permission boundary (documented tradeoff).**
The policy prevents `IaC_user` from escalating its own privileges via an explicit
`Deny` on `iam:*` against its own user identity and customer-managed policies.
Because an explicit `Deny` always wins in IAM's evaluation logic, the user cannot
rewrite its own policy to grant itself more access.

A **permission boundary** would be the more robust, textbook control for this: a
boundary is a separate object attached to the principal that caps its *maximum*
effective permissions no matter what policies are later attached — it survives
someone accidentally attaching a broad policy, which a single inline `Deny` in
one policy does not. The inline `Deny` was chosen here because a boundary is a
second managed object with its own admin lifecycle (create, attach, keep in
sync), which is more machinery than a disposable single-user lab account
warrants; the `Deny` delivers most of the protection in one object. **This is a
conscious tradeoff, and converting to a permission boundary is a reasonable
Week-2 hardening task** — noted here rather than silently decided so the
reasoning is on the record.

### Cost and blast-radius controls

Every resource carries `default_tags` (`Project`, `Scenario`, `ManagedBy`,
`TTLMinutes`) and every S3 bucket is `force_destroy = true`, so `terraform
destroy` always fully cleans up — including intentionally-public buckets and
their decoy contents. A $10 AWS Budget with alerts backs this up. Public-access
is disabled at the **bucket** level, never the account level, so the blast radius
of the misconfiguration is a single named bucket.

---

## Scenario 01 — S3 Data Exfiltration

**Status:** deployed, attacked, and detected end-to-end (then torn down).
**Difficulty:** beginner. **TTL:** 60 min.

### Vulnerability mechanics

The scenario stands up a VPC, a public-subnet EC2 "app server," and an S3 bucket
used for "customer exports" holding a decoy CSV. The vulnerability is that the
bucket is readable by anyone on the internet, with no authentication.

A modern S3 bucket only becomes truly public when **two** independent controls
both fail, and the Terraform sets up both on purpose (`scenarios/01-s3-exfil/terraform/s3.tf`):

1. **Block Public Access is disabled** on the bucket
   (`aws_s3_bucket_public_access_block` with all four flags `false`). Since 2023
   AWS defaults these to `true` on every new bucket specifically to prevent
   accidental exposure, so this must be actively turned off.
2. **A bucket policy grants read to everyone** — `Principal: { AWS: "*" }` with
   `s3:GetObject` / `s3:ListBucket` (`aws_s3_bucket_policy.data_public_read`).

This two-lock model is why the scenario is realistic rather than a strawman: a
single fat-fingered setting is no longer enough to expose a bucket. The common
real-world sequence is that step 1 happens first and innocently (someone disables
BPA to unblock an unrelated policy change) and step 2 follows later, with nothing
left to stop it. A `depends_on` forces Terraform to disable BPA *before*
attaching the policy, mirroring that order and avoiding an apply-time race where
AWS would reject the policy.

Note the contrast with the EC2 instance role
(`scenarios/01-s3-exfil/terraform/ec2.tf`): it is scoped to just this bucket's
ARN. The compute layer is fine; the bucket policy is the whole vulnerability.

### Attack automation workflow

Script: `scenarios/01-s3-exfil/scripts/attack.sh`. It reads the target from
`terraform output` (never hardcodes a bucket name) and proves exfiltration two
independent ways, both with **zero AWS credentials**:

1. **Anonymous S3 API listing** — `aws s3 ls s3://<bucket>/ --recursive
   --no-sign-request`. `--no-sign-request` tells the CLI to send no SIGv4
   signature at all, so this is an unauthenticated caller enumerating the bucket.
2. **Unauthenticated HTTPS GET** — `curl` against the object's public URL. `curl`
   sends no AWS auth headers whatsoever; a plain web request pulls the file.

**Verified result (2026-08-22, 15:21 UTC):** step 1 listed
`customer_exports/customers_2026.csv`; step 2 returned **HTTP 200** and
downloaded the full 76-byte CSV. The exfiltration path is confirmed real, from
an identity-less caller.

### Detection logic

Script: `scenarios/01-s3-exfil/scripts/detect.sh`. The trail
(`scenarios/01-s3-exfil/terraform/cloudtrail.tf`) enables **S3 data events** on
the data bucket — object-level logging that is off by default and without which
anonymous `GetObject` calls would never appear in CloudTrail at all. The script
syncs the raw log files and filters them with `jq`.

**The detection signal is the caller's lack of identity**, not its IP or user
agent (an attacker controls both). An anonymous S3 request is logged with:

```json
"userIdentity": { "type": "AWSAccount", "principalId": "", "accountId": "anonymous" }
```

So the detection matches: `eventSource == s3.amazonaws.com` **and**
`requestParameters.bucketName == <data bucket>` **and**
`userIdentity.accountId == "anonymous"` **and**
`eventName in ("GetObject", "ListObjects")`.

**Verified findings (second attack run, 15:46 UTC):** both the anonymous
`GetObject` (curl exfil of the CSV) and the anonymous `ListObjects` (the
`aws s3 ls` enumeration) were captured, each with `accountId: "anonymous"`.

Three empirical results that changed the design rather than being assumed:

1. **`ListBucket` was the wrong event name.** The anonymous `aws s3 ls` is logged
   as **`ListObjects`**, not `ListBucket` — `ListBucket` is the *IAM permission*
   name, not the CloudTrail *event* name. A detection query filtering on
   `ListBucket` would silently miss the enumeration. The manifest and script use
   `ListObjects`.
2. **Data-event logging has an activation gap.** The *first* attack ran seconds
   after `terraform apply` created the trail and produced **zero** data events
   across 20 minutes / 17 delivered log files, despite the trail reporting
   `IsLogging: true` with no delivery error. The identical second attack, run
   after the trail had been live ~25 minutes, was captured within ~5.5 minutes.
   Object-level data-event logging is not retroactive and takes a few minutes to
   arm after trail creation. **Implication for the cycle:** deploy → *wait a few
   minutes* → attack → wait for delivery → detect. Attacking immediately after
   apply yields a false "clean" result.
3. **Management events are not enough.** Before data events armed, the only
   S3 records touching the bucket were `GetBucketEncryption`/`GetBucketLogging`
   from AWS's own scanners — the attack itself was absent. Object-level data
   events are mandatory for this detection.

**Athena as the scale-up.** Parsing raw logs with `jq` is ideal for one bucket
and one incident and keeps the evidence visible. At many buckets or long time
ranges it does not scale; the productionized version defines an Athena table over
the CloudTrail S3 prefix and runs the same predicate as SQL
(`WHERE useridentity.accountid = 'anonymous' AND eventname IN ('GetObject','ListObjects')`).
Deferred deliberately — the raw-log proof is the teaching artifact.

### Remediation (the defense half)

- Re-enable S3 Block Public Access on the bucket (and, in a real account, at the
  account level).
- Remove the wildcard-principal statement from the bucket policy.
- If public read is genuinely required, front the bucket with CloudFront + Origin
  Access Control instead of a public bucket policy, so objects are never directly
  reachable.

### Teardown

`terraform destroy`. All buckets are `force_destroy = true`, so the decoy object
and both buckets are removed cleanly.
