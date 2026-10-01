#!/usr/bin/env bash
set -euo pipefail

# Slow storage can exceed the upstream entrypoint's two-minute startup wait.
entrypoint=$(mktemp -t pxc-entrypoint.XXXXXX)
sed 's/for i in {120\.\.0}/for i in {600..0}/' /entrypoint.sh > "$entrypoint"
exec bash "$entrypoint" "$@"
