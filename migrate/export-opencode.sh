#!/usr/bin/env bash
# export-opencode.sh — pack opencode session history + config for the move.
#
# Runs in the OLD distro (e.g. FedoraLinux-44). Writes a tar.gz to
# /mnt/c so Windows (and the cellar) can pick it up.
#
# Usage:
#   ./export-opencode.sh [output-dir]     # default: /mnt/c/Users/randy

set -Eeuo pipefail

USER_NAME="${SUDO_USER:-$USER}"
HOME_DIR="$(getent passwd "$USER_NAME" | cut -d: -f6)"
OUTPUT_DIR="${1:-/mnt/c/Users/randy}"
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
# Exclude transient/volatile files: logs change while opencode is running
# (including this very session) and would make tar fail mid-archive.
tar --exclude="*/opencode/log" \
	--exclude="*/opencode/*.log" \
	--exclude="*/opencode/node_modules" \
	-czf "$ARCHIVE" \
	-C "$HOME_DIR" \
	.local/share/opencode \
	.config/opencode

SUMMARY="$(du -h "$ARCHIVE" | cut -f1)"
echo "Wrote: $ARCHIVE ($SUMMARY)"
echo
echo "Next, inside the cellar:"
echo "  migrate/import-opencode.sh $ARCHIVE"
