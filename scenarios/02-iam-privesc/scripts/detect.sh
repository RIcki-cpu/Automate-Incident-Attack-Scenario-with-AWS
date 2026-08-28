#!/usr/bin/env bash
# Scenario 02 — IAM Privilege Escalation :: DETECT
#
# Finds the escalation in CloudTrail: the analyst user calling
# sts:AssumeRole against the broad-read role. Unlike Scenario 1, this
# looks at a MANAGEMENT event (on by default) rather than a data event —
# see terraform/cloudtrail.tf for why no special activation was needed.
#
# The detection signal is WHO called AssumeRole against WHICH role, not
# just that an AssumeRole happened at all — legitimate AssumeRole calls
# are common in any AWS account, so the query names both sides of the
# relationship: this specific low-privilege identity, assuming this
# specific role it should never have been trusted for.
set -euo pipefail

TF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../terraform" && pwd)"
ROLE_ARN="$(terraform -chdir="$TF_DIR" output -raw broad_read_role_arn)"
LOGBUCKET="$(terraform -chdir="$TF_DIR" output -raw trail_logs_bucket)"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
ROLE_NAME="$(basename "$ROLE_ARN")"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "[*] Syncing CloudTrail logs from s3://${LOGBUCKET} ..."
aws s3 sync "s3://${LOGBUCKET}/AWSLogs/${ACCOUNT_ID}/CloudTrail/" "$WORK" --quiet

echo "[*] Searching for AssumeRole calls against ${ROLE_NAME}:"
echo

MATCHES="$(find "$WORK" -name '*.json.gz' -exec zcat {} \; 2>/dev/null \
  | jq -c --arg role "$ROLE_NAME" '
      .Records[]?
      | select(.eventSource=="sts.amazonaws.com" and .eventName=="AssumeRole")
      | select((.requestParameters.roleArn // "") | endswith($role))
      | {eventTime,eventName,caller:(.userIdentity.arn // .userIdentity.userName // "unknown"),ip:.sourceIPAddress,agent:.userAgent}
    ')"

if [ -z "$MATCHES" ]; then
  echo "  (no AssumeRole calls against ${ROLE_NAME} found yet — check CloudTrail's"
  echo "   ~5-15 min delivery lag, or confirm the attack actually ran)"
  exit 0
fi

echo "$MATCHES" | jq -r '"  [\(.eventTime)] \(.eventName)  by=\(.caller)  ip=\(.ip)  agent=\(.agent)"'
echo
COUNT="$(echo "$MATCHES" | wc -l)"
echo "[!] DETECTED ${COUNT} AssumeRole call(s) against ${ROLE_NAME}."
echo "    Confirm the 'by=' identity is the analyst user (not something"
echo "    legitimate) before treating this as confirmed escalation."
