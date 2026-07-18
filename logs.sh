#!/usr/bin/env bash
# logs.sh — follow logs from both clients (Ctrl+C to exit)
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

# Optional: pass a service name, e.g. ./logs.sh geth  or  ./logs.sh beacon
SERVICE="${1:-}"

if [[ -n "${SERVICE}" ]]; then
  if docker compose logs -f --tail=200 "${SERVICE}" 2>/dev/null; then
    exit 0
  fi
  sudo docker compose logs -f --tail=200 "${SERVICE}"
else
  if docker compose logs -f --tail=200 2>/dev/null; then
    exit 0
  fi
  sudo docker compose logs -f --tail=200
fi
