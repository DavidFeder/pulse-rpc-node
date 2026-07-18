# pulse-rpc-node

**Run your own PulseChain full node as a private RPC** — simple enough for beginners, solid enough for daily wallet use.

This project starts:

| Client | Role | Official image |
|--------|------|----------------|
| **Go-Pulse** (geth) | Execution layer + JSON-RPC | `registry.gitlab.com/pulsechaincom/go-pulse:latest` |
| **Prysm-Pulse** Beacon | Consensus layer | `registry.gitlab.com/pulsechaincom/prysm-pulse/beacon-chain:latest` |

Use it with **MetaMask**, **Internet Money**, and other wallets instead of a public RPC.

---

## Quick start

On a Linux machine (Ubuntu/Debian recommended) with at least one free disk for chain data:

```bash
git clone https://github.com/DavidFeder/pulse-rpc-node.git
cd pulse-rpc-node
chmod +x install.sh
./install.sh
```

That’s it. The installer installs Docker if needed, prepares `/blockchain`, creates a JWT secret, pulls the official images, and starts the node.

---

## Hardware recommendations

Be honest with your hardware — PulseChain includes full Ethereum history up to the fork, so requirements are real:

| Resource | Comfortable | Minimum that can work |
|----------|-------------|------------------------|
| **RAM** | **32 GB+** | 16 GB (expect pressure / swapping) |
| **Storage** | **2 TB+ NVMe SSD** | 1 TB+ fast SSD (full node; plan headroom for growth) |
| **CPU** | 4+ modern cores | 4 cores |
| **Network** | Stable broadband, preferably unmetered | Required for initial sync & peers |

- **SSD is effectively required.** HDDs are too slow for a reliable modern full node.
- Initial sync can take **hours to days**. Checkpoint sync speeds up the beacon client a lot.
- Archive nodes need far more disk (many TB) — this stack is aimed at a normal full node + private RPC.

---

## ⚠ Security warnings (please read)

By default this stack **exposes RPC to your entire local network**:

| Port | Service |
|------|---------|
| **8545** | HTTP JSON-RPC (wallets use this) |
| **8546** | WebSocket RPC |
| **3500** | Beacon HTTP API |

**Do:**

- Run this on a **trusted home / lab network** behind your router’s firewall.
- Keep the machine updated and only allow people you trust on that LAN.

**Don’t:**

- **Never port-forward** 8545, 8546, or 3500 to the public internet.
- Don’t treat this as a public RPC endpoint for the world.
- Don’t expose Engine API / admin surfaces carelessly (this compose is for private wallet RPC use).

LAN exposure is intentional so phones and other PCs on your Wi‑Fi can use `http://YOUR_LAN_IP:8545`. If you only need the node on the same machine, see [Localhost-only mode](#localhost-only-mode) below.

---

## Step-by-step install

### 1. Requirements

- Linux (Ubuntu 22.04 / 24.04 or Debian recommended)
- `sudo` access
- Enough free space on the disk that will hold `/blockchain`
- Outbound internet (to pull images and sync)

### 2. Clone and install

```bash
git clone https://github.com/DavidFeder/pulse-rpc-node.git
cd pulse-rpc-node
chmod +x install.sh start.sh stop.sh restart.sh logs.sh update.sh
./install.sh
```

What `install.sh` does:

1. Checks privileges (prefers normal user + sudo)
2. Installs **Docker Engine + Compose plugin** if missing (Ubuntu/Debian)
3. Creates **`/blockchain`** and sets permissions
4. Generates **`/blockchain/jwt.hex`** if missing (`openssl rand -hex 32`)
5. Copies `.env.example` → `.env` if needed
6. Runs `docker compose pull` and `docker compose up -d`
7. Prints your LAN IP and MetaMask settings

### 3. Wait for sync

```bash
./logs.sh
```

- **Beacon** usually catches up faster thanks to **checkpoint sync** (`https://checkpoint.pulsechain.com`).
- **Execution (geth)** needs peers and will take longer to fully sync.
- Your RPC may answer before the node is fully synced — for safety, wait until both clients look healthy before sending important transactions.

### 4. Find your LAN IP

The installer prints it. You can also run:

```bash
hostname -I | awk '{print $1}'
```

---

## Connect a wallet

### MetaMask

1. MetaMask → **Networks** → **Add network** → **Add a network manually**
2. Enter:

| Field | Value |
|-------|--------|
| **Network Name** | PulseChain |
| **New RPC URL** | `http://YOUR_LAN_IP:8545` |
| **Chain ID** | `369` |
| **Currency Symbol** | `PLS` |
| **Block explorer URL** | `https://scan.pulsechain.com` |

Example: if your node PC is `192.168.1.50`, use `http://192.168.1.50:8545`.

### Internet Money / other wallets

Use the same network parameters:

- **RPC:** `http://YOUR_LAN_IP:8545`
- **Chain ID:** `369`
- **Symbol:** `PLS`
- **Explorer:** `https://scan.pulsechain.com`

Phone wallets must be on the **same Wi‑Fi / LAN** as the node (unless you set up a VPN — advanced, not covered here).

---

## Everyday commands

Run these from the project directory (`pulse-rpc-node/`):

| Action | Command |
|--------|---------|
| Follow logs | `./logs.sh` |
| Logs for geth only | `./logs.sh geth` |
| Logs for beacon only | `./logs.sh beacon` |
| Stop | `./stop.sh` |
| Start | `./start.sh` |
| Restart | `./restart.sh` |
| Update images & restart | `./update.sh` |

Equivalent Compose commands:

```bash
docker compose logs -f
docker compose down
docker compose up -d
docker compose pull && docker compose up -d
```

Chain data lives in **`/blockchain`** and is kept when you stop containers.

---

## Localhost-only mode

Default binds RPC to `0.0.0.0` (all interfaces → LAN). To allow **only this machine**:

1. Edit `docker-compose.yml`.
2. Change geth:

   - `--http.addr=0.0.0.0` → `--http.addr=127.0.0.1`
   - `--ws.addr=0.0.0.0` → `--ws.addr=127.0.0.1`

3. Change beacon (optional):

   - `--http-host=0.0.0.0` → `--http-host=127.0.0.1`
   - `--rpc-host=0.0.0.0` → `--rpc-host=127.0.0.1`

4. Restart:

```bash
./restart.sh
```

Then use `http://127.0.0.1:8545` in wallets **on the same computer only**.

---

## Ports overview

| Port | Protocol | Purpose | Default bind |
|------|----------|---------|--------------|
| 8545 | TCP | HTTP RPC (wallets) | `0.0.0.0` (LAN) |
| 8546 | TCP | WebSocket RPC | `0.0.0.0` (LAN) |
| 3500 | TCP | Beacon HTTP API | `0.0.0.0` (LAN) |
| 8551 | TCP | Engine API (geth ↔ beacon, JWT) | localhost (host network) |
| 30303 | TCP/UDP | Geth P2P | host |
| 13000 | TCP | Beacon P2P | host |
| 12000 | UDP | Beacon P2P | host |

For better peer connectivity, allow **inbound** P2P on 30303 / 13000 / 12000 on your router if you know how. **Do not** forward the RPC ports (8545, 8546, 3500).

---

## Configuration notes

- **Network:** PulseChain **mainnet** (`--pulsechain`), Chain ID **369**
- **Data directory:** `/blockchain` (JWT at `/blockchain/jwt.hex`)
- **Checkpoint sync:** enabled via `https://checkpoint.pulsechain.com`
- **Restart policy:** `unless-stopped`
- **Stop grace period:** `5m` (clean DB shutdown)
- **Network mode:** `host` (simplest P2P, matches official examples)
- **`.env` / `.env.example`:** reserved for light future options; v1 keeps compose flags explicit

---

## Troubleshooting

| Symptom | What to try |
|---------|-------------|
| `permission denied` talking to Docker | Log out and back in after install (docker group), or use `sudo docker compose ...` |
| Beacon says no execution client | Wait for geth to start; confirm `/blockchain/jwt.hex` exists and both containers share it |
| Wallet can’t connect | Same LAN? Correct IP? Firewall on the node? Try `curl http://127.0.0.1:8545` on the node |
| Disk filling up | Full nodes grow over time — use a large SSD and monitor free space |
| Very slow sync | Prefer NVMe, more RAM, and open P2P ports if possible |

```bash
# Quick health checks on the node machine
docker compose ps
curl -s -X POST http://127.0.0.1:8545 \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}'
```

If `eth_syncing` returns `false`, the execution client believes it is synced.

---

## Project layout

```
pulse-rpc-node/
├── README.md
├── docker-compose.yml   # geth + beacon
├── .env.example
├── install.sh           # one-command setup
├── start.sh
├── stop.sh
├── restart.sh
├── logs.sh
└── update.sh
```

---

## Credits

- **Go-Pulse** (execution): [gitlab.com/pulsechaincom/go-pulse](https://gitlab.com/pulsechaincom/go-pulse)
- **Prysm-Pulse** (consensus): [gitlab.com/pulsechaincom/prysm-pulse](https://gitlab.com/pulsechaincom/prysm-pulse)
- **Official mainnet docs:** [gitlab.com/pulsechaincom/pulsechain-mainnet](https://gitlab.com/pulsechaincom/pulsechain-mainnet)
- **Checkpoint sync:** [checkpoint.pulsechain.com](https://checkpoint.pulsechain.com)
- **Explorer:** [scan.pulsechain.com](https://scan.pulsechain.com)

This project is a convenience wrapper around the **official PulseChain Docker images**. It is not affiliated with PulseChain Core unless stated otherwise.

---

## License

MIT — see [LICENSE](LICENSE) if present; otherwise free to use and adapt for personal and community node setups.
