#!/usr/bin/env bash
# Scenario 01 — S3 Data Exfiltration :: DETECT
#
# Finds the anonymous (unauthenticated) access to the data bucket in
# CloudTrail S3 data events. The detection signal is NOT the source IP or
# user agent (an attacker controls both) — it is that the caller has no
# identity: userIdentity.accountId == "anonymous".
#
# This parses the raw CloudTrail log files with jq rather than using
# Athena. The raw event IS the evidence, and it needs no extra infra —
# see docs/technical-design.md for the Athena version as a scale-up.
#
# IMPORTANT nuances proven empirically for this scenario:
#   * S3 object-level "data events" must be enabled on the trail or these
#     calls are never logged (management events alone will not show them).
#   * Data-event logging is NOT retroactive and takes a few minutes to
#     arm after the trail is created — an attack in that window is
#     invisible. Attack AFTER the trail has been live a few minutes.
#   * The anonymous `aws s3 ls` is logged as eventName "ListObjects",
#     NOT "ListBucket" (that is the IAM permission name, not the event).
set -euo pipefail

TF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../terraform" && pwd)"
DATABUCKET="$(terraform -chdir="$TF_DIR" output -raw data_bucket_name)"
LOGBUCKET="$(terraform -chdir="$TF_DIR" output -raw trail_logs_bucket)"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "[*] Syncing CloudTrail logs from s3://${LOGBUCKET} ..."
aws s3 sync "s3://${LOGBUCKET}/AWSLogs/${ACCOUNT_ID}/CloudTrail/" "$WORK" --quiet

echo "[*] Searching for ANONYMOUS data-plane access to ${DATABUCKET}:"
echo

MATCHES="$(find "$WORK" -name '*.json.gz' -exec zcat {} \; 2>/dev/null \
  | jq -c --arg b "$DATABUCKET" '
      .Records[]?
      | select(.eventSource=="s3.amazonaws.com")
      | select(.requestParameters.bucketName==$b)
      | select(.userIdentity.accountId=="anonymous" or .userIdentity.type=="AWSAccount" and (.userIdentity.principalId//"")=="")
      | select(.eventName=="GetObject" or .eventName=="ListObjects")
      | {eventTime,eventName,ip:.sourceIPAddress,agent:.userAgent,who:.userIdentity.accountId,key:.requestParameters.key}
    ')"

if [ -z "$MATCHES" ]; then
  echo "  (no anonymous access found — did the attack run BEFORE the trail's"
  echo "   data-event logging armed, or within the ~5-15 min delivery lag?)"
  exit 0
fi

echo "$MATCHES" | jq -r '"  [\(.eventTime)] \(.eventName)  by=\(.who)  ip=\(.ip)  agent=\(.agent)  key=\(.key // "-")"'
echo
COUNT="$(echo "$MATCHES" | wc -l)"
echo "[!] DETECTED ${COUNT} anonymous S3 data-event(s) — unauthenticated read/exfil confirmed."
