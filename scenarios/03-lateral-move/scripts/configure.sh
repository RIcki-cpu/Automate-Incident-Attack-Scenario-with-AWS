#!/usr/bin/env bash
# Scenario 03 — CONFIGURE (Ansible)
#
# Generates the Ansible inventory from `terraform output`, creates the
# "pivot" key pair (the credential the attacker will later find leaked on
# the bastion), and runs the playbook to put both hosts into the scenario
# state. Run this AFTER `terraform apply`, BEFORE scripts/attack.sh.
#
# The private host (B) has no public IP, so Ansible reaches it by hopping
# through the public host (A) — that's the ProxyCommand in the inventory
# below. Uses the project venv's ansible (never bare `ansible`).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="$HERE/../terraform"
ANSIBLE_DIR="$HERE/../ansible"
REPO_ROOT="$(cd "$HERE/../../.." && pwd)"

WEB_IP="$(terraform -chdir="$TF_DIR" output -raw web_public_ip)"
INTERNAL_IP="$(terraform -chdir="$TF_DIR" output -raw internal_private_ip)"

# The operator's private key (matches the public key Terraform uploaded).
# Adjust if yours isn't the ed25519 default.
OPERATOR_KEY="${OPERATOR_KEY:-$HOME/.ssh/id_ed25519}"

# 1) Generate the pivot key pair (gitignored keys/ dir) if not present.
mkdir -p "$ANSIBLE_DIR/keys"
if [ ! -f "$ANSIBLE_DIR/keys/pivot_key" ]; then
  ssh-keygen -t ed25519 -N "" -f "$ANSIBLE_DIR/keys/pivot_key" -C "lateral-move-pivot" >/dev/null
  echo "[*] Generated pivot key pair (ansible/keys/pivot_key)"
fi

# 2) Write the inventory. B is reached via A using ProxyCommand; both use
#    the operator key for Ansible management.
cat > "$ANSIBLE_DIR/inventory.ini" <<INV
[web]
web ansible_host=${WEB_IP} ansible_user=ec2-user ansible_ssh_private_key_file=${OPERATOR_KEY}

[internal]
internal ansible_host=${INTERNAL_IP} ansible_user=ec2-user ansible_ssh_private_key_file=${OPERATOR_KEY} ansible_ssh_common_args='-o ProxyCommand="ssh -W %h:%p -o StrictHostKeyChecking=no -i ${OPERATOR_KEY} ec2-user@${WEB_IP}"'
INV
echo "[*] Wrote inventory (web=${WEB_IP}, internal=${INTERNAL_IP} via ProxyCommand)"

# 3) Run the playbook with the project venv's ansible.
cd "$ANSIBLE_DIR"
"$REPO_ROOT/.venv/bin/ansible-playbook" -i inventory.ini playbook.yml
echo "[*] Hosts configured. Next: scripts/attack.sh"
