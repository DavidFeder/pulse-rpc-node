#!/usr/bin/env bash
# update.sh — pull latest official images and recreate containers
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

echo "Pulling latest PulseChain images..."
run_compose pull

echo "Recreating containers with new images..."
run_compose up -d

echo "Update complete."
echo "Follow logs with: ./logs.sh"
