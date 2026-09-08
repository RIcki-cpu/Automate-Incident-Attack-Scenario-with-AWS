# Optional: remote Terraform state (S3 backend)

By default every scenario keeps its Terraform state in a **local** file — clone
the repo and it just works, no extra setup. This document is for the optional
best-practice upgrade: keeping state in a shared, versioned, encrypted **S3
bucket** instead, so it survives your laptop, can be rolled back, and is safe to
collaborate on.

It uses **S3-native state locking** (Terraform ≥ 1.10's `use_lockfile`), so —
unlike the older AWS pattern — **no DynamoDB lock table is needed**. Everything
(the bucket included) is created by Terraform. The only manual step is the same
one every scenario needs: attaching the deploy IAM policy.

## Why you might want it

- **Durability & history** — state lives in a versioned bucket, not one laptop; a
  bad `apply`/`destroy` can be rolled back to a previous version.
- **Encryption & privacy** — state can contain sensitive values; the bucket is
  SSE-encrypted and fully public-access-blocked.
- **Locking** — S3-native locking stops two runs from corrupting state at once.
- It's a portfolio-worthy demonstration of doing Terraform state the right way.

## One-time setup

The state bucket needs `tfstate-*` S3 permissions on the deploy user. Make sure
the current [`iam/iac-user-policy.json`](../iam/iac-user-policy.json) is attached
(the `ScenarioBucketsOnly` statement now includes `tfstate-*`), then:

```bash
cd state-backend
terraform init
terraform apply          # creates bucket tfstate-<your-account-id>
```

## Opt a scenario in

```bash
scripts/remote-state.sh enable scenarios/01-s3-exfil/terraform
```

This writes a `backend.tf` into that scenario (gitignored — it's your local
choice, never committed) pointing at `s3://tfstate-<account>/01-s3-exfil/terraform.tfstate`,
and migrates the existing state into S3. Repeat per scenario you want on remote
state.

## Opt back out

```bash
scripts/remote-state.sh disable scenarios/01-s3-exfil/terraform
```

Removes the `backend.tf` and migrates state back to a local file.

## How the pieces fit

- `state-backend/` — the one-time bootstrap that creates the bucket. It uses
  **local** state itself (a bucket can't store the state of the config that
  creates it — the chicken-and-egg every remote-state setup has to break).
- `scripts/remote-state.sh` — flips a scenario between local and remote state and
  runs the `terraform init -migrate-state` for you.
- `backend.tf` (inside a scenario, gitignored) — the actual backend block; present
  only when you've opted that scenario in.

## Teardown

`cd state-backend && terraform destroy` removes the bucket — but it refuses while
the bucket still holds state versions (deliberate; you don't want to wipe state
by accident). Empty it first, or re-apply with `-var force_destroy=true` before
destroying. Opt scenarios back out (`disable`) before tearing the bucket down.
