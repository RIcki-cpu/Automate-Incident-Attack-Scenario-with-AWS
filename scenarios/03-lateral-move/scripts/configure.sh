#!/usr/bin/env bash
# Scenario 03 — CONFIGURE (Ansible)
#
# Plants the leaked pivot key on the WEB host. Run this AFTER `terraform
# apply`, BEFORE scripts/attack.sh.
#
# The internal host configures itself at boot (Terraform user_data), so this
# only touches the web host — no hop into the private host, which is exactly
# what keeps the VPC Flow Logs detection clean (the only web->internal SSH
# flow is the attack). Uses the project venv's ansible (never bare ansible).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="$HERE/../terraform"
ANSIBLE_DIR="$HERE/../ansible"
REPO_ROOT="$(cd "$HERE/../../.." && pwd)"

WEB_IP="$(terraform -chdir="$TF_DIR" output -raw web_public_ip)"
OPERATOR_KEY="${OPERATOR_KEY:-$HOME/.ssh/id_ed25519}"

# 1) Pull the pivot PRIVATE key from terraform output into the gitignored
#    keys/ dir (never printed, never committed).
mkdir -p "$ANSIBLE_DIR/keys"
terraform -chdir="$TF_DIR" output -raw pivot_private_key > "$ANSIBLE_DIR/keys/pivot_key"
chmod 600 "$ANSIBLE_DIR/keys/pivot_key"
echo "[*] Wrote pivot private key to ansible/keys/pivot_key"

# 2) Inventory: just the web host (no ProxyJump — we never touch B here).
cat > "$ANSIBLE_DIR/inventory.ini" <<INV
[web]
web-host ansible_host=${WEB_IP} ansible_user=ec2-user ansible_ssh_private_key_file=${OPERATOR_KEY}
INV
echo "[*] Wrote inventory (web=${WEB_IP})"

# 3) Run the playbook with the project venv's ansible.
cd "$ANSIBLE_DIR"
"$REPO_ROOT/.venv/bin/ansible-playbook" -i inventory.ini playbook.yml
echo "[*] Web host configured. Next: scripts/attack.sh"
