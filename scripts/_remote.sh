#!/usr/bin/env bash
SSH_USER="${SSH_USER:-ubuntu}"
SSH_KEY="${SSH_KEY:-${HOME}/.ssh/jenkins-master.key}"
ssh_opts=(
  -i "${SSH_KEY}"
  -o IdentitiesOnly=yes
  -o StrictHostKeyChecking=no
  -o LogLevel=ERROR
  -o BatchMode=yes
)
remote_primary() { 
  if [ -z "${PRIMARY_HOST:-}" ]; then echo "PRIMARY_HOST not set, skipping remote." >&2; return 0; fi
  ssh "${ssh_opts[@]}" "${SSH_USER}@${PRIMARY_HOST}" "$@"
}
remote_secondary() { 
  if [ -z "${SECONDARY_HOST:-}" ]; then echo "SECONDARY_HOST not set, skipping remote." >&2; return 0; fi
  ssh "${ssh_opts[@]}" "${SSH_USER}@${SECONDARY_HOST}" "$@"
}
