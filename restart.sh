#!/usr/bin/env bash
# restart.sh — restart the PulseChain node stack
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

echo "Restarting node..."
run_compose restart
echo "Node restarted."
echo "Follow logs with: ./logs.sh"
