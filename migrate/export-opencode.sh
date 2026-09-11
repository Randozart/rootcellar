#!/usr/bin/env bash
# export-opencode.sh — pack opencode session history + config for the move.
#
# Runs in the OLD distro (e.g. FedoraLinux-44). Writes a tar.gz to
# /mnt/c so Windows (and the cellar) can pick it up.
#
# Usage:
#   ./export-opencode.sh [output-dir]     # default: /mnt/c/Users/<you>

set -Eeuo pipefail

USER_NAME="${SUDO_USER:-$USER}"
HOME_DIR="$(getent passwd "$USER_NAME" | cut -d: -f6)"
OUTPUT_DIR="${1:-/mnt/c/Users/$(whoami)}"
STAMP="$(date +%F)"
ARCHIVE="$OUTPUT_DIR/opencode-backup-$STAMP.tar.gz"

if [[ ! -d "$HOME_DIR/.local/share/opencode" ]]; then
	echo "No opencode data found at $HOME_DIR/.local/share/opencode" >&2
	exit 66
fi

if [[ ! -d "$OUTPUT_DIR" ]]; then
	echo "Output dir not accessible: $OUTPUT_DIR (is /mnt/c mounted?)" >&2
	exit 66
fi

echo "Packing opencode data (this can take a while — sessions are large)..."

# Stage to /tmp first: opencode.db is live SQLite while opencode runs
# (including this very session), so raw tar aborts on it. sqlite3 .backup
# produces a consistent copy; the rest is copied best-effort.
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

mkdir -p "$STAGE/share" "$STAGE/config"
cp -a "$HOME_DIR/.local/share/opencode/." "$STAGE/share/" 2>/dev/null || true
cp -a "$HOME_DIR/.config/opencode/." "$STAGE/config/" 2>/dev/null || true

if command -v sqlite3 >/dev/null 2>&1 && [[ -f "$HOME_DIR/.local/share/opencode/opencode.db" ]]; then
	sqlite3 "$HOME_DIR/.local/share/opencode/opencode.db" ".backup '$STAGE/share/opencode.db'"
	log_tool="sqlite3 .backup"
else
	echo "WARN: sqlite3 missing — opencode.db copied live (may be torn)" >&2
fi

# Transient logs only — session_diff is history, it ships.
rm -rf "$STAGE/share/log" 2>/dev/null || true

tar -czf "$ARCHIVE" -C "$STAGE" share config

SUMMARY="$(du -h "$ARCHIVE" | cut -f1)"
echo "Wrote: $ARCHIVE ($SUMMARY) [db via ${log_tool:-live copy}]"
echo
echo "Next, inside the cellar:"
echo "  migrate/import-opencode.sh $ARCHIVE"
