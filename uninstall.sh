#!/usr/bin/env bash
# ============================================================================
# BytesPulse AV — Complete Uninstaller
# curl -fsSL https://raw.githubusercontent.com/BytesPulse-OE/bytespulse-av-releases/main/uninstall.sh | sudo bash
# ============================================================================
set -euo pipefail

GREEN='\033[0;32m' YELLOW='\033[0;33m' NC='\033[0m'
step()  { echo -e "${GREEN}[✓]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
info()  { echo -e "    $*"; }

[ "$EUID" -eq 0 ] || { echo "Run as root: sudo bash uninstall.sh" >&2; exit 1; }

echo ""
echo -e "╔══════════════════════════════════════════════════════╗"
echo    "║         BytesPulse AV — Uninstaller                 ║"
echo -e "╚══════════════════════════════════════════════════════╝"
echo ""
echo "This will remove BytesPulse AV completely:"
echo "  • Stop and disable the bpav daemon"
echo "  • Remove the binary, service, config, logs, scan history"
echo "  • Remove the HestiaCP plugin"
echo "  • Remove the post_install hook"
echo ""
read -r -p "Are you sure? [yes/N] " confirm
[ "$confirm" = "yes" ] || { echo "Aborted."; exit 0; }
echo ""

# ── 1. Stop and disable the daemon ───────────────────────────────────────────
step "Stopping and disabling daemon"
if systemctl is-active --quiet bpav 2>/dev/null; then
    systemctl stop bpav
    info "Service stopped"
fi
if systemctl is-enabled --quiet bpav 2>/dev/null; then
    systemctl disable --quiet bpav
    info "Service disabled"
fi

# ── 2. Remove systemd service ─────────────────────────────────────────────────
step "Removing systemd service"
rm -f /etc/systemd/system/bpav.service
rm -rf /etc/systemd/system/bpav.service.d
systemctl daemon-reload
info "Removed /etc/systemd/system/bpav.service"

# ── 3. Remove binary ──────────────────────────────────────────────────────────
step "Removing daemon binary"
rm -f /usr/local/bin/bpav-daemon
info "Removed /usr/local/bin/bpav-daemon"

# ── 4. Remove HestiaCP plugin ─────────────────────────────────────────────────
step "Removing HestiaCP plugin"
HESTIA_WEB="/usr/local/hestia/web"
if [ -d "$HESTIA_WEB" ]; then
    # Remove deployed files
    rm -f  "$HESTIA_WEB/list/bpav/index.php"
    rm -f  "$HESTIA_WEB/list/bpav/ajax.php"
    rmdir  "$HESTIA_WEB/list/bpav" 2>/dev/null || true
    rm -f  "$HESTIA_WEB/templates/pages/list_bpav.php"
    info "Removed /usr/local/hestia/web/list/bpav/"
    info "Removed /usr/local/hestia/web/templates/pages/list_bpav.php"

    # Remove the scan link from list_web.php
    LIST_WEB="$HESTIA_WEB/templates/pages/list_web.php"
    if [ -f "$LIST_WEB" ] && grep -q "bp-bpav-scan-link" "$LIST_WEB"; then
        python3 - "$LIST_WEB" <<'PYEOF'
import re, sys
path = sys.argv[1]
with open(path) as f:
    content = f.read()
content = re.sub(
    r'\s*<!-- bp-bpav-scan-link -->.*?</li>\n',
    '', content, flags=re.DOTALL
)
with open(path, 'w') as f:
    f.write(content)
print("    Removed scan link from list_web.php")
PYEOF
    fi

    # Restore any .bpav-backup-* files for prevent_csrf.php (safety)
    PREVENT_CSRF="$HESTIA_WEB/inc/prevent_csrf.php"
    BACKUP="$(ls -t "${PREVENT_CSRF}".bpav-backup-* 2>/dev/null | head -1 || true)"
    if [ -n "$BACKUP" ]; then
        cp -f "$BACKUP" "$PREVENT_CSRF"
        rm -f "${PREVENT_CSRF}".bpav-backup-*
        info "Restored prevent_csrf.php from backup"
    fi
else
    warn "HestiaCP not found at /usr/local/hestia — skipping plugin removal"
fi

# ── 5. Remove post_install hook ───────────────────────────────────────────────
step "Removing post_install hook"
HOOK_FILE="/etc/hestiacp/hooks/post_install.sh"
if [ -f "$HOOK_FILE" ] && grep -q "BytesPulse AV" "$HOOK_FILE"; then
    sed -i '/---- BytesPulse AV/,/---- End BytesPulse AV/d' "$HOOK_FILE"
    info "Removed BytesPulse AV block from $HOOK_FILE"
    # If the hook file is now empty (or only the shebang), remove it
    if [ "$(grep -c '[^[:space:]]' "$HOOK_FILE" || true)" -le 2 ]; then
        rm -f "$HOOK_FILE"
        info "Removed empty $HOOK_FILE"
    fi
fi

# ── 6. Remove plugin source files ────────────────────────────────────────────
step "Removing plugin source files"
rm -rf /etc/bpav/hestia-plugin
info "Removed /etc/bpav/hestia-plugin/"

# ── 7. Remove scan history from all users ────────────────────────────────────
step "Removing scan history from all users"
removed_users=0
for home_dir in /home/*/; do
    # username for readability only
    scan_dir="$home_dir/.bpav"
    if [ -d "$scan_dir" ]; then
        rm -rf "$scan_dir"
        info "Removed $scan_dir"
        removed_users=$(( removed_users + 1 ))
    fi
done
[ "$removed_users" -gt 0 ] && info "Cleaned scan history for $removed_users user(s)"

# ── 8. Remove configuration, logs, known shells ──────────────────────────────
step "Removing configuration and logs"
rm -rf /etc/bpav
rm -rf /var/log/bpav
info "Removed /etc/bpav/"
info "Removed /var/log/bpav/"

# ── 9. Remove runtime directory ──────────────────────────────────────────────
step "Removing runtime directory"
rm -rf /run/bpav
info "Removed /run/bpav/"

# ── 10. Remove wp-cli (only if we installed it) ───────────────────────────────
if [ -f /usr/local/bin/wp ]; then
    echo ""
    read -r -p "Remove wp-cli (/usr/local/bin/wp)? [y/N] " wp_confirm
    if [ "$wp_confirm" = "y" ] || [ "$wp_confirm" = "Y" ]; then
        rm -f /usr/local/bin/wp
        step "Removed wp-cli"
    else
        warn "wp-cli kept at /usr/local/bin/wp"
    fi
fi

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo -e "╔══════════════════════════════════════════════════════╗"
echo    "║         BytesPulse AV — Uninstall Complete          ║"
echo -e "╚══════════════════════════════════════════════════════╝"
echo ""
echo "  BytesPulse AV has been completely removed."
echo "  No processes, files, or services remain."
echo ""
