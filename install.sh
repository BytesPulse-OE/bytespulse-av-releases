#!/usr/bin/env bash
# ============================================================================
# BytesPulse AV — One-line installer
# curl -fsSL https://raw.githubusercontent.com/BytesPulse-OE/bytespulse-av-releases/main/install.sh | sudo bash
# ============================================================================
set -euo pipefail

REPO_BASE="https://github.com/BytesPulse-OE/bytespulse-av-releases/releases/latest/download"
RAW_BASE="https://raw.githubusercontent.com/BytesPulse-OE/bytespulse-av-releases/main"

DAEMON_BIN="/usr/local/bin/bpav-daemon"
CONFIG_DIR="/etc/bpav"
LOG_DIR="/var/log/bpav"
RUN_DIR="/run/bpav"
PLUGIN_TMP="/tmp/bpav-plugin-install"

GREEN='\033[0;32m' RED='\033[0;31m' YELLOW='\033[0;33m' NC='\033[0m'
step()  { echo -e "${GREEN}[✓]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
err()   { echo -e "${RED}[✗]${NC} $*"; exit 1; }

[ "$EUID" -eq 0 ] || err "Run as root: sudo bash install.sh"

echo -e "\n╔══════════════════════════════════════════════════════╗"
echo    "║         BytesPulse AV — Installation               ║"
echo -e "╚══════════════════════════════════════════════════════╝\n"

# ── 1. Architecture ──────────────────────────────────────────────────────
step "Detecting system architecture"
ARCH="$(uname -m)"
case "$ARCH" in
    x86_64)  ARCH_TAG="amd64" ;;
    aarch64) ARCH_TAG="arm64" ;;
    *) err "Unsupported architecture: $ARCH" ;;
esac
echo "   Architecture: $ARCH ($ARCH_TAG)"

# ── 2. Dependencies ───────────────────────────────────────────────────────
step "Checking dependencies"
MISSING=()
for dep in curl unzip python3; do
    command -v "$dep" &>/dev/null || MISSING+=("$dep")
done
if [ "${#MISSING[@]}" -gt 0 ]; then
    warn "Installing missing dependencies: ${MISSING[*]}"
    apt-get install -y "${MISSING[@]}" -qq 2>/dev/null || \
        err "Could not install: ${MISSING[*]}"
fi

OPTIONAL_MISSING=()
for dep in mysql dig openssl; do
    command -v "$dep" &>/dev/null || OPTIONAL_MISSING+=("$dep")
done
command -v wp &>/dev/null || OPTIONAL_MISSING+=("wp")
[ "${#OPTIONAL_MISSING[@]}" -gt 0 ] && \
    warn "Missing optional dependencies: ${OPTIONAL_MISSING[*]}"

# ── 3. wp-cli ─────────────────────────────────────────────────────────────
if ! command -v wp &>/dev/null; then
    step "Installing wp-cli"
    curl -sS -o /usr/local/bin/wp \
        https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
    chmod +x /usr/local/bin/wp
    echo "   wp-cli installed"
fi

# ── 4. Directories ────────────────────────────────────────────────────────
step "Creating directories"
mkdir -p "$CONFIG_DIR" "$LOG_DIR" "$RUN_DIR"
chmod 750 "$CONFIG_DIR" "$LOG_DIR"
chmod 755 "$RUN_DIR"

# ── 5. Daemon binary ──────────────────────────────────────────────────────
step "Installing daemon binary"
if curl -fsSL --retry 3 \
    "${REPO_BASE}/bpav-daemon-linux-${ARCH_TAG}" -o "$DAEMON_BIN"; then
    chmod +x "$DAEMON_BIN"
    echo "   Binary: $DAEMON_BIN"
else
    err "Could not download daemon binary from ${REPO_BASE}/bpav-daemon-linux-${ARCH_TAG}"
fi

# ── 6. Default config ─────────────────────────────────────────────────────
step "Writing default configuration"
if [ ! -f "$CONFIG_DIR/config.json" ]; then
    cat > "$CONFIG_DIR/config.json" << CFGEOF
{
  "enabled": true,
  "listen_addr": ":7443",
  "socket_path": "/run/bpav/bpav.sock",
  "home_dir": "/home",
  "hestia_users_dir": "/usr/local/hestia/data/users",
  "log_dir": "/var/log/bpav",
  "data_dir": "/etc/bpav",
  "schedule_enabled": true,
  "schedule_day": "friday",
  "schedule_hour": 6,
  "max_workers": 2,
  "since_date": "$(date -d '90 days ago' +%Y-%m-%d 2>/dev/null || date -v-90d +%Y-%m-%d 2>/dev/null || echo '2026-06-01')",
  "default_language": "en",
  "google_safe_browsing_key": "",
  "wpvulndb_token": ""
}
CFGEOF
    echo "   Config: $CONFIG_DIR/config.json"
fi

# ── 7. Admin API key ──────────────────────────────────────────────────────
step "Generating admin API key"
if [ ! -f "$CONFIG_DIR/admin_token.txt" ]; then
    ADMIN_TOKEN="$(openssl rand -hex 32)"
    echo "$ADMIN_TOKEN" > "$CONFIG_DIR/admin_token.txt"
    chmod 600 "$CONFIG_DIR/admin_token.txt"
    echo ""
    echo -e "   ${GREEN}Admin API token: $ADMIN_TOKEN${NC}"
    echo "   SAVE THIS — it will not be shown again."
    echo ""
fi

# ── 8. Known shell hashes ─────────────────────────────────────────────────
step "Fetching known webshell hash database"
if curl -sf --max-time 15 \
    "${RAW_BASE}/known_shells.sha256" \
    -o "$CONFIG_DIR/known_shells.sha256" 2>/dev/null; then
    COUNT="$(wc -l < "$CONFIG_DIR/known_shells.sha256")"
    echo "   $COUNT shell hashes loaded"
else
    warn "Could not fetch shell hashes — SHA256 matching disabled until available"
fi

# ── 9. systemd service ────────────────────────────────────────────────────
step "Installing systemd service"
cat > /etc/systemd/system/bpav.service << SVCEOF
[Unit]
Description=BytesPulse AV Security Scanner Daemon
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/bpav-daemon
Restart=on-failure
RestartSec=5
RuntimeDirectory=bpav
RuntimeDirectoryMode=0755
CPUQuota=40%
MemoryMax=512M
NoNewPrivileges=yes
ProtectSystem=strict
ReadWritePaths=/etc/bpav /var/log/bpav /run/bpav /home

[Install]
WantedBy=multi-user.target
SVCEOF

systemctl daemon-reload
systemctl enable --quiet bpav
systemctl restart bpav
sleep 2
if systemctl is-active --quiet bpav; then
    echo "   Service: active ✓"
else
    warn "Service not active — check: journalctl -u bpav -n 20"
fi

# ── 10. HestiaCP plugin ───────────────────────────────────────────────────
step "Installing HestiaCP plugin"
if [ ! -d "/usr/local/hestia" ]; then
    warn "HestiaCP not found at /usr/local/hestia — skipping plugin install"
else
    rm -rf "$PLUGIN_TMP"
    mkdir -p "$PLUGIN_TMP"

    if curl -fsSL --retry 3 \
        "${REPO_BASE}/plugin.zip" -o "$PLUGIN_TMP/plugin.zip"; then
        unzip -q "$PLUGIN_TMP/plugin.zip" -d "$PLUGIN_TMP/"
        bash "$PLUGIN_TMP/install.sh"
        rm -rf "$PLUGIN_TMP"
        echo "   HestiaCP plugin installed ✓"
    else
        warn "Could not download plugin.zip — run after next release"
        rm -rf "$PLUGIN_TMP"
    fi
fi

# ── 11. Runtime directory ─────────────────────────────────────────────────
step "Configuring runtime directory"
mkdir -p "$RUN_DIR"
chmod 755 "$RUN_DIR"

# ── Done ──────────────────────────────────────────────────────────────────
HOSTNAME_VAL="$(hostname -f 2>/dev/null || hostname)"

echo ""
echo -e "╔══════════════════════════════════════════════════════╗"
echo    "║         BytesPulse AV — Installation Complete       ║"
echo -e "╚══════════════════════════════════════════════════════╝"
echo "  Daemon:   systemctl status bpav"
echo "  Logs:     tail -f /var/log/bpav/daemon.log"
echo "  Config:   /etc/bpav/config.json"
echo "  Health:   curl -s http://localhost:7443/api/v1/health"
echo "  Panel:    https://${HOSTNAME_VAL}:8083/list/bpav/"
echo "  Token:    cat /etc/bpav/admin_token.txt"
echo ""
echo "  Next steps:"
echo "  1. Open https://${HOSTNAME_VAL}:8083/list/bpav/ in your browser"
echo "  2. Add Google Safe Browsing key to config (optional)"
echo "  3. Add WPVulnDB token to config (optional)"
