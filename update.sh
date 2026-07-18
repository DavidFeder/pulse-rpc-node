#!/usr/bin/env bash
# update.sh — pull latest official images and recreate containers
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

echo "Pulling latest PulseChain images..."
if docker compose pull 2>/dev/null; then
  :
else
  sudo docker compose pull
fi

echo "Recreating containers with new images..."
if docker compose up -d 2>/dev/null; then
  :
else
  sudo docker compose up -d
fi

echo "Update complete."
echo "Follow logs with: ./logs.sh"
