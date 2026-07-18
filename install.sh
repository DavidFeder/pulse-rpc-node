#!/usr/bin/env bash
# install.sh — one-command setup for pulse-rpc-node
# Installs Docker (if needed), prepares /blockchain, generates JWT, starts the node.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()  { echo -e "${CYAN}→${NC} $*"; }
ok()    { echo -e "${GREEN}✓${NC} $*"; }
warn()  { echo -e "${YELLOW}⚠${NC}  $*"; }
err()   { echo -e "${RED}✗${NC} $*" >&2; }
die()   { err "$*"; exit 1; }

echo ""
echo -e "${BOLD}========================================${NC}"
echo -e "${BOLD}  pulse-rpc-node installer${NC}"
echo -e "${BOLD}  PulseChain private RPC (mainnet)${NC}"
echo -e "${BOLD}========================================${NC}"
echo ""

# ---------------------------------------------------------------------------
# 1. Root / sudo check
# ---------------------------------------------------------------------------
if [[ "${EUID}" -eq 0 ]]; then
  warn "You are running as root."
  warn "This works, but running as a normal user with sudo is safer and recommended."
  echo ""
  SUDO=""
else
  if ! command -v sudo >/dev/null 2>&1; then
    die "sudo is required when not running as root. Install sudo or re-run as root."
  fi
  # Ensure we can use sudo without a surprise mid-script
  if ! sudo -n true 2>/dev/null; then
    info "This script needs sudo for Docker install and /blockchain setup."
    sudo -v || die "Could not obtain sudo privileges."
  fi
  SUDO="sudo"
  # Keep sudo credential cache warm during long steps
  (while true; do sudo -n true; sleep 50; done) 2>/dev/null &
  SUDO_KEEPALIVE_PID=$!
  trap 'kill "${SUDO_KEEPALIVE_PID}" 2>/dev/null || true' EXIT
fi

# ---------------------------------------------------------------------------
# 2. Detect OS (Ubuntu/Debian focused)
# ---------------------------------------------------------------------------
if [[ -f /etc/os-release ]]; then
  # shellcheck source=/dev/null
  . /etc/os-release
  OS_ID="${ID:-unknown}"
else
  OS_ID="unknown"
fi

case "${OS_ID}" in
  ubuntu|debian|linuxmint|pop)
    ok "Detected Debian-family OS: ${OS_ID}"
    ;;
  *)
    warn "OS '${OS_ID}' is not Ubuntu/Debian. Docker install may need to be done manually."
    warn "If Docker + Compose are already installed, the rest of this script should still work."
    ;;
esac

# ---------------------------------------------------------------------------
# 3. Install Docker + Compose plugin if missing
# ---------------------------------------------------------------------------
need_docker_install=false
if ! command -v docker >/dev/null 2>&1; then
  need_docker_install=true
elif ! docker compose version >/dev/null 2>&1; then
  need_docker_install=true
fi

if [[ "${need_docker_install}" == true ]]; then
  info "Installing Docker Engine + Compose plugin..."
  case "${OS_ID}" in
    ubuntu|debian|linuxmint|pop)
      $SUDO apt-get update -y
      $SUDO apt-get install -y ca-certificates curl gnupg openssl
      $SUDO install -m 0755 -d /etc/apt/keyrings
      if [[ ! -f /etc/apt/keyrings/docker.asc ]]; then
        $SUDO curl -fsSL "https://download.docker.com/linux/${OS_ID}/gpg" -o /etc/apt/keyrings/docker.asc \
          || $SUDO curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
        $SUDO chmod a+r /etc/apt/keyrings/docker.asc
      fi
      # Prefer matching distro; fall back to ubuntu codename mapping
      DOCKER_DISTRO="${OS_ID}"
      DOCKER_CODENAME="${VERSION_CODENAME:-stable}"
      if [[ "${OS_ID}" != "ubuntu" && "${OS_ID}" != "debian" ]]; then
        DOCKER_DISTRO="ubuntu"
        DOCKER_CODENAME="${UBUNTU_CODENAME:-${VERSION_CODENAME:-jammy}}"
      fi
      echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/${DOCKER_DISTRO} ${DOCKER_CODENAME} stable" \
        | $SUDO tee /etc/apt/sources.list.d/docker.list >/dev/null
      $SUDO apt-get update -y
      $SUDO apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
      $SUDO systemctl enable --now docker
      ok "Docker installed."
      ;;
    *)
      die "Automatic Docker install is only supported on Ubuntu/Debian. Install Docker manually: https://docs.docker.com/engine/install/ then re-run this script."
      ;;
  esac
else
  ok "Docker and Compose plugin already available."
fi

# Ensure openssl for JWT generation
if ! command -v openssl >/dev/null 2>&1; then
  info "Installing openssl..."
  $SUDO apt-get update -y && $SUDO apt-get install -y openssl || die "Please install openssl and re-run."
fi

# Allow current user to run docker without sudo (best-effort)
if [[ "${EUID}" -ne 0 ]]; then
  if ! groups | grep -qw docker; then
    info "Adding ${USER} to the docker group (log out/in may be required)..."
    $SUDO usermod -aG docker "${USER}" || warn "Could not add user to docker group."
    # Try to use newgrp-style access for this session via sg if needed later
  fi
fi

# Helper: run docker, with sudo fallback if permission denied
docker_cmd() {
  if docker "$@" 2>/dev/null; then
    return 0
  fi
  if [[ "${EUID}" -ne 0 ]]; then
    $SUDO docker "$@"
  else
    docker "$@"
  fi
}

compose_cmd() {
  if docker compose "$@" 2>/dev/null; then
    return 0
  fi
  if [[ "${EUID}" -ne 0 ]]; then
    $SUDO docker compose "$@"
  else
    docker compose "$@"
  fi
}

# ---------------------------------------------------------------------------
# 4. Prepare /blockchain
# ---------------------------------------------------------------------------
info "Preparing data directory /blockchain ..."
$SUDO mkdir -p /blockchain
$SUDO chmod 755 /blockchain

# Prefer ownership by current user so docker (host network) and scripts can write
if [[ "${EUID}" -ne 0 ]]; then
  $SUDO chown -R "${USER}:${USER}" /blockchain 2>/dev/null || true
fi
ok "/blockchain is ready."

# ---------------------------------------------------------------------------
# 5. JWT secret (required for Engine API between geth and beacon)
# ---------------------------------------------------------------------------
JWT_PATH="/blockchain/jwt.hex"
if [[ -f "${JWT_PATH}" ]]; then
  ok "JWT secret already exists at ${JWT_PATH}"
else
  info "Generating JWT secret at ${JWT_PATH} ..."
  # No trailing newline (required by clients)
  openssl rand -hex 32 | tr -d '\n' | $SUDO tee "${JWT_PATH}" >/dev/null
  $SUDO chmod 644 "${JWT_PATH}"
  if [[ "${EUID}" -ne 0 ]]; then
    $SUDO chown "${USER}:${USER}" "${JWT_PATH}" 2>/dev/null || true
  fi
  ok "JWT secret created."
fi

# ---------------------------------------------------------------------------
# 6. .env from example
# ---------------------------------------------------------------------------
if [[ ! -f .env ]]; then
  if [[ -f .env.example ]]; then
    cp .env.example .env
    ok "Created .env from .env.example"
  else
    warn ".env.example not found; continuing without .env"
  fi
else
  ok ".env already present"
fi

# ---------------------------------------------------------------------------
# 7. Pull images + start stack
# ---------------------------------------------------------------------------
info "Pulling official PulseChain Docker images (this may take a few minutes)..."
compose_cmd pull || die "Failed to pull images. Check your internet connection and try again."

info "Starting node containers..."
compose_cmd up -d || die "Failed to start containers. Run: docker compose logs"

# ---------------------------------------------------------------------------
# 8. Success message
# ---------------------------------------------------------------------------
# Best-effort LAN IP detection
LAN_IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
if [[ -z "${LAN_IP}" ]]; then
  LAN_IP="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1); exit}}')"
fi
if [[ -z "${LAN_IP}" ]]; then
  LAN_IP="YOUR_LAN_IP"
fi

echo ""
echo -e "${GREEN}${BOLD}========================================${NC}"
echo -e "${GREEN}${BOLD}  Node is starting!${NC}"
echo -e "${GREEN}${BOLD}========================================${NC}"
echo ""
echo -e "  Containers: ${BOLD}pulse-geth${NC} + ${BOLD}pulse-beacon${NC}"
echo -e "  Data dir:   ${BOLD}/blockchain${NC}"
echo -e "  Network:    ${BOLD}PulseChain Mainnet${NC} (chain id 369)"
echo ""
echo -e "${YELLOW}${BOLD}SECURITY REMINDER${NC}"
echo -e "  RPC ports ${BOLD}8545${NC}, ${BOLD}8546${NC}, and beacon ${BOLD}3500${NC} are open on your LAN."
echo -e "  Use only on a trusted home network. ${BOLD}Do not${NC} port-forward them to the internet."
echo ""
echo -e "${BOLD}Connect MetaMask / Internet Money:${NC}"
echo -e "  Network Name:  PulseChain"
echo -e "  RPC URL:       ${CYAN}http://${LAN_IP}:8545${NC}"
echo -e "  Chain ID:      369"
echo -e "  Symbol:        PLS"
echo -e "  Explorer:      https://scan.pulsechain.com"
echo ""
echo -e "${BOLD}Useful commands (from this directory):${NC}"
echo -e "  ./logs.sh          # follow logs"
echo -e "  ./stop.sh          # stop node"
echo -e "  ./start.sh         # start node"
echo -e "  ./restart.sh       # restart node"
echo -e "  ./update.sh        # pull latest images & restart"
echo ""
echo -e "  Or:  docker compose logs -f"
echo ""
echo -e "${CYAN}Note:${NC} Initial sync can take hours to days depending on hardware and bandwidth."
echo -e "      Checkpoint sync speeds up the beacon client. Wait until both clients report as synced"
echo -e "      before relying on the RPC for transactions."
echo ""
ok "Install complete."
echo ""
