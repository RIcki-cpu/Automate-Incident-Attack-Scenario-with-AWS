#!/usr/bin/env bash
# Scenario 03 — DETECT (VPC Flow Logs via CloudWatch Logs Insights)
#
# Finds the lateral movement in the network record: an ACCEPTED flow from
# the web host's private IP to the internal host's private IP on port 22.
# That A->B:22 flow should never happen (the web tier has no business
# opening SSH to the data tier) — it is the signature of the pivot.
#
# Unlike scenarios 1 and 2 (which grepped CloudTrail JSON from S3 with jq),
# this queries CloudWatch Logs Insights — the standard tool for Flow Logs.
# Insight queries run server-side and return async, so we start the query,
# then poll for results.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="$HERE/../terraform"

LOG_GROUP="$(terraform -chdir="$TF_DIR" output -raw flow_log_group)"
# Flow Logs record the in-VPC (private) addresses, so match on those:
WEB_PRIV="$(aws ec2 describe-instances --instance-ids "$(terraform -chdir="$TF_DIR" output -raw web_instance_id)" --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text)"
INTERNAL_PRIV="$(terraform -chdir="$TF_DIR" output -raw internal_private_ip)"

echo "[*] Log group: ${LOG_GROUP}"
echo "[*] Looking for accepted flows ${WEB_PRIV} -> ${INTERNAL_PRIV} on port 22"
echo

# Flow Logs default fields: ... srcaddr dstaddr srcport dstport protocol ... action ...
# Insights exposes them as srcAddr/dstAddr/dstPort/action.
QUERY="fields @timestamp, srcAddr, dstAddr, dstPort, action
| filter srcAddr = \"${WEB_PRIV}\" and dstAddr = \"${INTERNAL_PRIV}\" and dstPort = 22 and action = \"ACCEPT\"
| sort @timestamp desc
| limit 20"

START=$(( $(date -u +%s) - 3600 ))   # last hour
END=$(date -u +%s)

QID="$(aws logs start-query \
  --log-group-name "$LOG_GROUP" \
  --start-time "$START" --end-time "$END" \
  --query-string "$QUERY" \
  --query queryId --output text)"

echo "[*] Started Logs Insights query $QID — waiting for results..."
for i in $(seq 1 30); do
  STATUS="$(aws logs get-query-results --query-id "$QID" --query 'status' --output text)"
  if [ "$STATUS" = "Complete" ]; then break; fi
  sleep 2
done

RESULTS="$(aws logs get-query-results --query-id "$QID" --output json)"
COUNT="$(echo "$RESULTS" | jq '.results | length')"

if [ "$COUNT" -eq 0 ]; then
  echo "  (no matching A->B:22 flows yet — Flow Logs can lag a few minutes;"
  echo "   confirm the attack ran, then re-run)"
  exit 0
fi

echo "$RESULTS" | jq -r '.results[] | map("\(.field)=\(.value)") | join("  ")'
echo
echo "[!] DETECTED ${COUNT} lateral SSH flow(s) from the web tier to the internal host."
echo "    The web tier opening SSH to the data tier is the lateral-movement signature."
