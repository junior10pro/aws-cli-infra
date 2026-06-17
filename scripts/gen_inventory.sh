#!/usr/bin/env bash
# Génère un inventaire Ansible INI à partir des outputs Terraform.
# Usage : KEY_FILE=~/.ssh/cle-td.pem bash scripts/gen_inventory.sh > ansible/inventory/hosts.ini
set -euo pipefail

KEY_FILE="${KEY_FILE:-~/.ssh/cle-td.pem}"

BASTION_IP=$(terraform output -raw bastion_ip)
SONDE_IP=$(terraform output -raw sonde_public_ip 2>/dev/null || echo "")
PRIVATE_IP=$(terraform output -raw private_ip 2>/dev/null || echo "")

PROXY_OPTS="-o ProxyJump=ec2-user@${BASTION_IP} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
BASE_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

cat <<EOF
# Inventaire généré automatiquement — ne pas éditer à la main
# Regénérer avec : make inventory

[bastion]
bastion ansible_host=${BASTION_IP} ansible_user=ec2-user

EOF

if [ -n "${SONDE_IP}" ]; then
cat <<EOF
[sonde]
sonde ansible_host=${SONDE_IP} ansible_user=ubuntu ansible_ssh_common_args='${PROXY_OPTS}'

EOF
fi

if [ -n "${PRIVATE_IP}" ]; then
cat <<EOF
[private]
private ansible_host=${PRIVATE_IP} ansible_user=ec2-user ansible_ssh_common_args='${PROXY_OPTS}'

EOF
fi

cat <<EOF
[all:vars]
ansible_ssh_private_key_file=${KEY_FILE}
ansible_ssh_common_args='${BASE_OPTS}'
EOF
