#!/usr/bin/env bash
# restart.sh — restart the PulseChain node stack
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

echo "Restarting node..."
if docker compose restart 2>/dev/null; then
  :
else
  sudo docker compose restart
fi

echo "Node restarted."
echo "Follow logs with: ./logs.sh"
