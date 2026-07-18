#!/usr/bin/env bash
# start.sh — start the PulseChain node stack
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

if docker compose up -d 2>/dev/null; then
  :
else
  sudo docker compose up -d
fi

echo "Node started (pulse-geth + pulse-beacon)."
echo "Follow logs with: ./logs.sh"
