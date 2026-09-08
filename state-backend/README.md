# Terraform remote-state backend (optional)

A one-time bootstrap that creates an S3 bucket to hold Terraform state for the
scenarios — versioned, encrypted, fully private, with **S3-native locking** (no
DynamoDB table needed). Using it is entirely optional: every scenario works with
local state out of the box. See [`../docs/remote-state.md`](../docs/remote-state.md)
for the full how-to.

## One-time setup

```bash
cd state-backend
terraform init
terraform apply        # creates bucket tfstate-<your-account-id>
```

(Needs the deploy policy's `tfstate-*` S3 permissions attached — see
[`../iam/README.md`](../iam/README.md).)

Then opt a scenario in to remote state:

```bash
../scripts/remote-state.sh enable ../scenarios/01-s3-exfil/terraform
# ... and `disable` to migrate back to local state.
```

## Teardown

```bash
terraform destroy      # fails if the bucket still holds state versions
```

To remove the bucket you must either empty it first, or re-apply with
`-var force_destroy=true` before destroying. That friction is deliberate — a
state bucket shouldn't be easy to wipe by accident.
