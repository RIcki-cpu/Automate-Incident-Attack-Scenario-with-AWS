#!/usr/bin/env bash
# Opt a scenario in (or out) of remote Terraform state in the shared S3
# backend bucket. Local state is the default for every scenario; this is
# purely optional and reversible.
#
#   scripts/remote-state.sh enable  scenarios/01-s3-exfil/terraform
#   scripts/remote-state.sh disable scenarios/01-s3-exfil/terraform
#
# enable  -> writes a (gitignored) backend.tf into the scenario and migrates
#            its state into s3://tfstate-<account>/<scenario>/terraform.tfstate
# disable -> removes backend.tf and migrates state back to a local file
#
# Prerequisite: run the bootstrap once (cd state-backend && terraform apply)
# so the bucket exists. Uses S3-native locking (no DynamoDB).
set -euo pipefail

ACTION="${1:-}"
TFDIR="${2:-}"
if [ "$ACTION" != "enable" ] && [ "$ACTION" != "disable" ] || [ -z "$TFDIR" ]; then
  echo "usage: $0 <enable|disable> <path-to-scenario-terraform-dir>" >&2
  exit 2
fi
if [ ! -d "$TFDIR" ]; then echo "no such dir: $TFDIR" >&2; exit 2; fi

REGION="${AWS_REGION:-us-east-1}"
ACCT="$(aws sts get-caller-identity --query Account --output text)"
BUCKET="tfstate-${ACCT}"
# Key = the scenario folder name, e.g. 01-s3-exfil/terraform.tfstate
KEY="$(basename "$(dirname "$(cd "$TFDIR" && pwd)")")/terraform.tfstate"

if [ "$ACTION" = "enable" ]; then
  if ! aws s3api head-bucket --bucket "$BUCKET" 2>/dev/null; then
    echo "state bucket $BUCKET not found — run 'cd state-backend && terraform apply' first." >&2
    exit 1
  fi
  cat > "$TFDIR/backend.tf" <<EOF
# Enabled by scripts/remote-state.sh (gitignored — a local, opt-in choice).
terraform {
  backend "s3" {
    bucket       = "${BUCKET}"
    key          = "${KEY}"
    region       = "${REGION}"
    encrypt      = true
    use_lockfile = true
  }
}
EOF
  echo "[*] Wrote $TFDIR/backend.tf -> s3://${BUCKET}/${KEY}"
  echo "[*] Migrating state to S3..."
  terraform -chdir="$TFDIR" init -migrate-state -force-copy -input=false
  echo "[*] Done. This scenario now uses remote state."
else
  if [ ! -f "$TFDIR/backend.tf" ]; then
    echo "no backend.tf in $TFDIR — already using local state." ; exit 0
  fi
  rm -f "$TFDIR/backend.tf"
  echo "[*] Removed backend.tf; migrating state back to local..."
  terraform -chdir="$TFDIR" init -migrate-state -force-copy -input=false
  echo "[*] Done. This scenario is back on local state."
fi
