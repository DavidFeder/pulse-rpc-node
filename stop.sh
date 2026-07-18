#!/usr/bin/env bash
# stop.sh — gracefully stop the PulseChain node stack
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

echo "Stopping node (grace period up to ~5 minutes for clean shutdown)..."
if docker compose down 2>/dev/null; then
  :
else
  sudo docker compose down
fi

echo "Node stopped. Chain data is preserved in /blockchain"
