#!/usr/bin/env bash
# =============================================================================
# BytesPulse AV — Server Installation Script
# Usage: curl -fsSL https://install.bytespulse.gr/av | sudo bash
# Or:    sudo bash install.sh
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GRN='\033[0;32m'; YEL='\033[1;33m'; NC='\033[0m'; BOLD='\033[1m'

DAEMON_BIN="/usr/local/bin/bpav-daemon"
SERVICE_FILE="/etc/systemd/system/bpav.service"
CONFIG_DIR="/etc/bpav"
LOG_DIR="/var/log/bpav"
PLUGIN_DIR="/usr/local/hestia/plugins/bytespulse-av"
HESTIA_CUSTOM="/usr/local/hestia/web/src/app/WebApp/Plugins"

REPO_BASE="https://github.com/BytesPulse-OE/bytespulse-av-releases/releases/latest/download"

step()  { echo -e "\n${BOLD}${GRN}[✓]${NC} $1"; }
warn()  { echo -e "${YEL}[!]${NC} $1"; }
fatal() { echo -e "${RED}[✗]${NC} $1"; exit 1; }

[ "$(id -u)" -eq 0 ] || fatal "Run as root: sudo bash install.sh"

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║         BytesPulse AV — Installation               ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

# --- 1. Detect architecture ---
step "Detecting system architecture"
ARCH=$(uname -m)
case "$ARCH" in
  x86_64)  ARCH_TAG="amd64" ;;
  aarch64) ARCH_TAG="arm64" ;;
  *)        fatal "Unsupported architecture: $ARCH" ;;
esac
echo "   Architecture: $ARCH ($ARCH_TAG)"

# --- 2. Check dependencies ---
step "Checking dependencies"
MISSING=()
for dep in curl mysql dig openssl wp; do
  if ! command -v "$dep" &>/dev/null; then
    MISSING+=("$dep")
  fi
done

if [ "${#MISSING[@]}" -gt 0 ]; then
  warn "Missing optional dependencies: ${MISSING[*]}"
  warn "Some scan modules may not work until these are installed."
fi

# wp-cli is required
if ! command -v wp &>/dev/null; then
  step "Installing wp-cli"
  curl -sS -o /usr/local/bin/wp \
    https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
  chmod +x /usr/local/bin/wp
  echo "   wp-cli installed"
fi

# --- 3. Create directories ---
step "Creating directories"
mkdir -p "$CONFIG_DIR" "$LOG_DIR"
chmod 700 "$CONFIG_DIR"
chmod 755 "$LOG_DIR"

# --- 4. Install daemon binary ---
step "Installing daemon binary"
if [ -f /tmp/bpav-daemon ]; then
  # Local build (dev mode)
  cp /tmp/bpav-daemon "$DAEMON_BIN"
else
  # Download from release
  curl -fsSL "${REPO_BASE}/bpav-daemon-linux-${ARCH_TAG}" -o "$DAEMON_BIN" \
    || fatal "Could not download daemon binary. Build from source: cd daemon && go build -o bpav-daemon ."
fi
chmod 755 "$DAEMON_BIN"
echo "   Binary: $DAEMON_BIN"

# --- 5. Generate initial config ---
step "Writing default configuration"
if [ ! -f "$CONFIG_DIR/config.json" ]; then
  HOSTNAME=$(hostname -f 2>/dev/null || hostname)
  cat > "$CONFIG_DIR/config.json" << EOF
{
  "enabled": true,
  "socket_path": "/run/bpav/bpav.sock",
  "api_port": 7443,
  "tls_cert": "",
  "tls_key": "",
  "log_dir": "/var/log/bpav",
  "hestia_dir": "/usr/local/hestia",
  "home_dir": "/home",
  "since_date": "$(date -d '90 days ago' '+%Y-%m-%d' 2>/dev/null || date '+%Y-%m-%d')",
  "dns_baseline_dir": "/etc/bpav/dns_baseline",
  "core_cache_dir": "/root/bpav-wp-cores",
  "known_shells_file": "/etc/bpav/known_shells.sha256",
  "max_workers": 2,
  "scan_timeout_secs": 3600,
  "mail_from": "security@${HOSTNAME}",
  "sendmail_bin": "/usr/sbin/sendmail",
  "google_safe_browsing_key": "",
  "wpvulndb_token": "",
  "schedule_enabled": true,
  "schedule_day": "friday",
  "schedule_hour": 6,
  "max_history_per_user": 10
}
EOF
  chmod 600 "$CONFIG_DIR/config.json"
  echo "   Config: $CONFIG_DIR/config.json"
else
  echo "   Config already exists — not overwritten"
fi

# --- 6. Generate initial admin API key ---
step "Generating admin API key"
if [ ! -f "$CONFIG_DIR/api_keys.json" ]; then
  ADMIN_TOKEN=$("$DAEMON_BIN" -gen-key -key-desc "Admin key" -key-owner admin 2>/dev/null \
    | grep "Token:" | awk '{print $2}' || true)
  if [ -n "$ADMIN_TOKEN" ]; then
    echo "   Admin API token: ${ADMIN_TOKEN}"
    echo "   SAVE THIS — it will not be shown again."
    echo "$ADMIN_TOKEN" > "$CONFIG_DIR/admin_token.txt"
    chmod 600 "$CONFIG_DIR/admin_token.txt"
  fi
fi

# --- 7. Download known shells SHA256 database ---
step "Fetching known webshell hash database"
curl -sf --max-time 15 \
  "https://raw.githubusercontent.com/BytesPulse-OE/bytespulse-av/main/known_shells.sha256" \
  -o "$CONFIG_DIR/known_shells.sha256" 2>/dev/null \
  || warn "Could not fetch shell hashes — will skip SHA256 matching until available"

# --- 8. Install systemd service ---
step "Installing systemd service"
if [ -f "$(dirname "$0")/bpav.service" ]; then
  cp "$(dirname "$0")/bpav.service" "$SERVICE_FILE"
else
  cat > "$SERVICE_FILE" << 'EOF'
[Unit]
Description=BytesPulse AV Security Daemon
After=network.target mysql.service mariadb.service

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/bpav-daemon -config /etc/bpav/config.json
Restart=on-failure
RestartSec=10s
StandardOutput=append:/var/log/bpav/daemon.log
StandardError=append:/var/log/bpav/daemon.log
CPUQuota=40%
MemoryMax=512M

[Install]
WantedBy=multi-user.target
EOF
fi

systemctl daemon-reload
systemctl enable bpav
systemctl start bpav
sleep 2

if systemctl is-active --quiet bpav; then
  echo "   Service: active ✓"
else
  warn "Service did not start — check: journalctl -u bpav -n 50"
fi

# --- 9. Install HestiaCP plugin ---
step "Installing HestiaCP plugin"
if [ -d "/usr/local/hestia" ]; then
  mkdir -p "$PLUGIN_DIR"
  # Copy plugin files (from repo or local)
  PLUGIN_SRC="$(dirname "$0")/../plugin"
  if [ -d "$PLUGIN_SRC" ]; then
    cp -r "$PLUGIN_SRC/." "$PLUGIN_DIR/"
    echo "   Plugin installed: $PLUGIN_DIR"
  else
    warn "Plugin files not found at $PLUGIN_SRC — install manually"
  fi
else
  warn "HestiaCP not found at /usr/local/hestia — skipping plugin install"
fi

# --- 10. Setup /run/bpav directory ---
step "Configuring runtime directory"
mkdir -p /run/bpav
chmod 750 /run/bpav

# Persist across reboots via tmpfiles.d
echo "d /run/bpav 0750 root root -" > /etc/tmpfiles.d/bpav.conf

# --- Done ---
echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║         BytesPulse AV — Installation Complete       ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
echo "  Daemon:   systemctl status bpav"
echo "  Logs:     tail -f /var/log/bpav/daemon.log"
echo "  Config:   $CONFIG_DIR/config.json"
echo "  API:      https://$(hostname):7443/api/v1/health"
echo "  Socket:   /run/bpav/bpav.sock"
echo ""
if [ -f "$CONFIG_DIR/admin_token.txt" ]; then
  echo "  Admin API token saved to: $CONFIG_DIR/admin_token.txt"
fi
echo ""
echo "  Next steps:"
echo "  1. Add Google Safe Browsing key to config (optional)"
echo "  2. Add WPVulnDB token to config (optional)"  
echo "  3. Configure TLS cert/key for the REST API"
echo "  4. Test: curl -s http://localhost:7443/api/v1/health"
echo ""
