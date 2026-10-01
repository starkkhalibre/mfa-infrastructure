#!/usr/bin/env bash
set -euo pipefail

host="${1:?host is required}"
port="${2:?port is required}"
timeout="${3:-120}"

deadline=$((SECONDS + timeout))

echo "Waiting up to ${timeout}s for ${host}:${port}..."

while (( SECONDS < deadline )); do
  if timeout 1 bash -c ":</dev/tcp/${host}/${port}" 2>/dev/null; then
    echo "${host}:${port} is reachable."
    exit 0
  fi

  sleep 2
done

echo "Timed out waiting for ${host}:${port}." >&2
exit 1
