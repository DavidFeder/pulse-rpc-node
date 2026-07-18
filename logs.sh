#!/usr/bin/env bash
# logs.sh — follow logs from both clients (Ctrl+C to exit)
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

# Optional: pass a service name, e.g. ./logs.sh geth  or  ./logs.sh beacon
SERVICE="${1:-}"

if [[ -n "${SERVICE}" ]]; then
  run_compose logs -f --tail=200 "${SERVICE}"
else
  run_compose logs -f --tail=200
fi
