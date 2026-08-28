# IAM setup for the deploying user

`iac-user-policy.json` is the least-privilege policy for the IAM user that runs
`terraform apply` in this repo (`IaC_user`). Terraform authenticates as this
user; everything in `scenarios/` is created under it.

## Why this exists

The deploying user needs to create VPCs, EC2 instances, S3 buckets, IAM roles,
and CloudTrail trails — but nothing beyond that, and specifically not the
ability to grant itself more access. Attaching `AdministratorAccess` would be
faster, but over-permissioned IAM is one of the misconfigurations this project
exists to teach people to detect, so it's scoped instead.

## How it's scoped

- **S3** is restricted by bucket-name prefix (`s3-exfil-*`, `iam-privesc-*`,
  `lateral-move-*`) — the user cannot touch buckets outside the scenarios.
- **IAM** is restricted to role and instance-profile names using those same
  scenario prefixes, so it can't read or modify unrelated roles.
- **`iam:PassRole`** is limited to scenario roles *and* conditioned on
  `iam:PassedToService = ec2.amazonaws.com`. Unconditional `PassRole` is itself
  a classic privilege-escalation path, though it's not what Scenario 02 ended
  up using — that scenario escalates via an overly-permissive **trust policy**
  (a role trusting the account's `:root` ARN) instead. Both are real,
  well-known IAM privesc patterns; see `docs/technical-design.md` for why the
  trust-policy version was chosen.
- **`ScenarioUsersOnly`** grants IAM *user* actions (`CreateUser`,
  `CreateAccessKey`, etc.) scoped to `user/iam-privesc-*` — added for Scenario
  02, which needs a real low-privilege user/access-key pair as its starting
  foothold. Scenario 01 never needed this; it only touched roles.
- **An explicit `Deny`** blocks the user from modifying its own IAM identity or
  any customer-managed policy, so it can't escalate its own privileges even if
  another statement is later widened by mistake.
- **EC2** actions are enumerated (not `ec2:*`) but apply account-wide, since
  EC2 resource-level permissions can't scope resources that don't exist yet.

## Applying it

This must be done by an admin/root identity — `IaC_user` cannot grant itself
permissions (that's the `Deny` above doing its job).

**Console:** IAM → Policies → Create policy → JSON tab → paste
`iac-user-policy.json` → name it `ScenarioKitDeployPolicy` → Create. Then
IAM → Users → `IaC_user` → Add permissions → attach that policy.

**CLI** (as an admin profile, not `IaC_user`):

```bash
aws iam create-policy \
  --policy-name ScenarioKitDeployPolicy \
  --policy-document file://iam/iac-user-policy.json

aws iam attach-user-policy \
  --user-name IaC_user \
  --policy-arn arn:aws:iam::<ACCOUNT_ID>:policy/ScenarioKitDeployPolicy
```

## Verifying

```bash
aws sts get-caller-identity                                    # confirm you are IaC_user
aws s3control get-public-access-block --account-id <ACCOUNT_ID>  # see note below
cd scenarios/01-s3-exfil/terraform && terraform plan
```

A clean `terraform plan` means the policy is sufficient.

## Account-level Block Public Access

Scenario 01 depends on being able to make a bucket public. If **account-level**
Block Public Access is enabled, AWS rejects the public bucket policy and the
bucket ends up not actually vulnerable — the attack step fails with `403` for
the wrong reason. Check it with the `get-public-access-block` command above:
`NoSuchPublicAccessBlockConfiguration` means it's off (good). If it's on, turn
it off in S3 → Block Public Access settings for this account, and only in a
dedicated lab account.

## Note on the account ID

The ARNs in `iac-user-policy.json` are hardcoded to this project's lab account.
If you fork this repo, replace `500926551923` with your own account ID.
