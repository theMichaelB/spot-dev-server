#!/bin/bash
set -euo pipefail

ANSIBLE_DIR="/opt/bootstrap/ansible"

echo "Running Ansible playbook..."

ansible-playbook \
    -i "${ANSIBLE_DIR}/inventory.ini" \
    "${ANSIBLE_DIR}/site.yml"

echo "Ansible playbook completed"
