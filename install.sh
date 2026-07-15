#!/usr/bin/env bash
# Serksi Agent — Docker installer
#
#   curl -sL https://get.serksi.com/install | sudo bash
#
# Installs Docker if needed, sets up the agent, and starts it. Then open
# https://<this-host-ip>:5443 in a browser to register.
#
# Options (environment variables):
#   INSTALL_DIR=/opt/serksi-agent   where to install (default shown)
#   SERKSI_INTERFACE=ens33          LAN interface (auto-detected if unset)

set -e
set -o pipefail

INSTALL_DIR="${INSTALL_DIR:-/opt/serksi-agent}"
COMPOSE_URL="https://get.serksi.com/docker-compose.yml"

log() { echo "[serksi] $*"; }
err() { echo "[serksi] ERROR: $*" >&2; }

# ── Checks ────────────────────────────────────────────────────────────────────
if [ "$(id -u)" -ne 0 ]; then
    err "Run with sudo:  curl -sL https://get.serksi.com/install | sudo bash"
    exit 1
fi

if [ "$(uname -s)" != "Linux" ]; then
    err "The Serksi agent requires Linux — it uses host networking to see your LAN."
    err "On Mac/Windows, run this inside a Linux VM bridged to the network you"
    err "want to monitor. Docker Desktop will not work."
    exit 1
fi

echo ""
echo "  ╔══════════════════════════════════════╗"
echo "  ║   Serksi Agent — Docker Installer    ║"
echo "  ╚══════════════════════════════════════╝"
echo ""

# ── Docker ────────────────────────────────────────────────────────────────────
if ! command -v curl >/dev/null 2>&1; then
    log "Installing curl..."
    (apt-get update -qq && apt-get install -y -qq curl) >/dev/null 2>&1 || {
        err "Could not install curl. Install it and re-run."; exit 1; }
fi

if ! command -v docker >/dev/null 2>&1; then
    log "Docker not found — installing from get.docker.com..."
    curl -fsSL https://get.docker.com | sh >/dev/null 2>&1 || {
        err "Docker installation failed. Install Docker manually and re-run."; exit 1; }
    systemctl enable --now docker >/dev/null 2>&1 || true
    log "Docker installed."
else
    log "Docker found: $(docker --version)"
fi

# Compose v2 ships as a plugin. Distro packages (e.g. Ubuntu's docker.io) often
# lack it, so fall back to Docker's official install script.
if ! docker compose version >/dev/null 2>&1; then
    log "Docker Compose v2 not found — installing..."
    curl -fsSL https://get.docker.com | sh >/dev/null 2>&1 || true
    if ! docker compose version >/dev/null 2>&1; then
        err "Docker Compose v2 is required but could not be installed."
        err "If Docker came from your distro's repo (apt install docker.io), it"
        err "does not include Compose v2 — install Docker from get.docker.com."
        exit 1
    fi
fi
log "Compose found: $(docker compose version --short 2>/dev/null || docker compose version)"

# ── Install ───────────────────────────────────────────────────────────────────
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

if [ -f docker-compose.yml ]; then
    log "Existing install found in $INSTALL_DIR — updating compose file."
    cp docker-compose.yml docker-compose.yml.bak
fi

log "Fetching docker-compose.yml..."
curl -fsSL "$COMPOSE_URL" -o docker-compose.yml || {
    err "Could not download the compose file from $COMPOSE_URL"; exit 1; }

# Only write .env if the caller asked for a specific interface. Otherwise the
# agent auto-detects, which is right on nearly every host.
if [ -n "$SERKSI_INTERFACE" ]; then
    echo "SERKSI_INTERFACE=$SERKSI_INTERFACE" > .env
    log "Pinned interface to $SERKSI_INTERFACE (.env)."
fi

log "Pulling the agent image..."
docker compose pull

log "Starting the agent..."
docker compose up -d

# ── Done ──────────────────────────────────────────────────────────────────────
HOST_IP="$(ip -4 route get 1 2>/dev/null | awk '{print $7; exit}')"
[ -z "$HOST_IP" ] && HOST_IP="<this-host-ip>"

sleep 2
echo ""
echo "  ─────────────────────────────────────────────────────────"
echo "   Serksi agent is running."
echo ""
echo "   Register it by opening:"
echo ""
echo "       https://${HOST_IP}:5443"
echo ""
echo "   Your browser will warn about the certificate — that's"
echo "   expected. The agent uses a self-signed certificate"
echo "   because no public authority can issue one for a private"
echo "   IP address. Click Advanced → Proceed."
echo "  ─────────────────────────────────────────────────────────"
echo ""
echo "   Installed in : $INSTALL_DIR"
echo "   Logs         : cd $INSTALL_DIR && docker compose logs -f"
echo "   Stop         : cd $INSTALL_DIR && docker compose down"
echo "   Update       : cd $INSTALL_DIR && docker compose pull && docker compose up -d"
echo ""