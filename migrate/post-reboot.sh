#!/usr/bin/env bash
set -euo pipefail

# post-reboot.sh — Run from FedoraLinux-44 AFTER wsl --shutdown
# Handles: rename rootcellar → RootCellar, opencode export/import
# Assumes: opencode is running in Fedora, rootcellar distro is accessible

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
step=0

log()  { step=$((step+1)); echo -e "\n${GREEN}[$step] $1${NC}"; }
warn() { echo -e "${YELLOW}⚠ $1${NC}"; }
fail() { echo -e "${RED}✗ $1${NC}"; exit 1; }

OLD_NAME="rootcellar"
NEW_NAME="RootCellar"
VHD_DIR="/mnt/c/wsl"
EXPORT_VHD="$VHD_DIR/${NEW_NAME}.vhdx"
REPO="/mnt/c/Users/$(whoami)/Documents/Projects/rootcellar"

# --- Pre-flight ---
[[ -d "$REPO" ]] || fail "Repo not found at $REPO"
command -v wsl.exe >/dev/null || fail "wsl.exe not in PATH"

log "Checking distro state..."
wsl.exe -l -v 2>&1 | tr -d '\0' | head -5

# ============================================================
# PHASE 1: Rename rootcellar → RootCellar (via VHD export/import)
# ============================================================

log "Terminating $OLD_NAME..."
wsl.exe --terminate "$OLD_NAME" 2>/dev/null || true
sleep 2

if wsl.exe -l -v 2>&1 | tr -d '\0' | grep -q "$NEW_NAME"; then
    warn "$NEW_NAME already exists — skipping rename"
else
    log "Exporting VHD for $OLD_NAME (fast — raw vhdx copy)..."
    mkdir -p "$VHD_DIR"
    wsl.exe --export "$OLD_NAME" "$EXPORT_VHD" --format vhd 2>&1 | tr -d '\0'
    [[ -f "$EXPORT_VHD" ]] || fail "VHD export failed"

    log "Importing as $NEW_NAME..."
    wsl.exe --import-in-place "$NEW_NAME" "$EXPORT_VHD" 2>&1 | tr -d '\0'

    log "Verifying $NEW_NAME boots..."
    VER=$(wsl.exe -d "$NEW_NAME" -u root -- uname -r 2>&1 | tr -d '\0' || true)
    echo "   uname -r: $VER"

    if wsl.exe -d "$NEW_NAME" -u root -- test -d /etc/cellar 2>&1 | tr -d '\0'; then
        log "Cellar directory present"
    else
        warn "/etc/cellar missing — check nixos-rebuild"
    fi

    log "Unregistering old $OLD_NAME..."
    wsl.exe --unregister "$OLD_NAME" 2>&1 | tr -d '\0' || true
    echo "   Old registration removed"
fi

# ============================================================
# PHASE 2: Export opencode data from Fedora
# ============================================================

log "Exporting opencode data from Fedora..."
"$REPO/migrate/export-opencode.sh"
ARCHIVE=$(ls -t "$HOME/Documents/Projects/rootcellar"/opencode-backup-*.tar.gz 2>/dev/null | head -1 \
       || ls -t /mnt/c/Users/"$(whoami)"/opencode-backup-*.tar.gz 2>/dev/null | head -1 || true)
[[ -n "$ARCHIVE" ]] || fail "Archive not found after export"

log "Archive ready: $ARCHIVE ($(du -h "$ARCHIVE" | cut -f1))"

# ============================================================
# PHASE 3: Import opencode data into RootCellar
# ============================================================

log "Importing opencode into $NEW_NAME..."
wsl.exe -d "$NEW_NAME" -u root -- /run/current-system/sw/bin/bash -c "
export PATH=/run/current-system/sw/bin:\$PATH
export NIX_CONFIG='experimental-features = nix-command flakes'
$REPO/migrate/import-opencode.sh '$ARCHIVE'
" 2>&1 | tr -d '\0'

log "Verifying import..."
wsl.exe -d "$NEW_NAME" -u root -- ls -la /home/"$(whoami)"/.local/share/opencode/ 2>&1 | tr -d '\0' | head -5

# ============================================================
# DONE
# ============================================================

echo ""
echo -e "${GREEN}══════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  RootCellar is ready!${NC}"
echo -e "${GREEN}══════════════════════════════════════════════════${NC}"
echo ""
echo "Next steps (run in PowerShell as Admin):"
echo "  cd C:\Users\<you>\Documents\Projects\rootcellar\windows"
echo "  .\\create-btrfs-vhd.ps1"
echo "  .\\register-scheduled-tasks.ps1"
echo "  .\\defender-exclusions.ps1"
echo ""
echo "Then launch:"
echo "  wsl -d $NEW_NAME"
echo "  opencode"
echo ""
