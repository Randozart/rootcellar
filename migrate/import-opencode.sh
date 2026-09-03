#!/usr/bin/env bash
# import-opencode.sh — restore opencode session history + config in the cellar.
#
# Usage:
#   ./import-opencode.sh /mnt/c/Users/randy/opencode-backup-YYYY-MM-DD.tar.gz

set -Eeuo pipefail

ARCHIVE="${1:-}"
USER_NAME="${SUDO_USER:-$USER}"
HOME_DIR="$(getent passwd "$USER_NAME" | cut -d: -f6)"
UID_N="$(id -u "$USER_NAME")"
GID_N="$(id -g "$USER_NAME")"

if [[ -z "$ARCHIVE" || ! -f "$ARCHIVE" ]]; then
	echo "usage: $0 <opencode-backup.tar.gz>" >&2
	exit 64
fi

if [[ $EUID -ne 0 ]]; then
	echo "Run with sudo: sudo $0 $ARCHIVE" >&2
	exit 77
fi

echo "This overwrites $HOME_DIR/.local/share/opencode and $HOME_DIR/.config/opencode."
read -r -p "Continue? [y/N] " reply
[[ "$reply" == "y" || "$reply" == "Y" ]] || {
	echo "Aborted."
	exit 1
}

mkdir -p "$HOME_DIR/.local/share" "$HOME_DIR/.config"

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

tar -xzf "$ARCHIVE" -C "$STAGE"

# Archive layout (see export-opencode.sh): share/ -> ~/.local/share/opencode,
# config/ -> ~/.config/opencode. Legacy layout (full .local/.config paths)
# is also accepted.
if [[ -d "$STAGE/share" ]]; then
	rm -rf "$HOME_DIR/.local/share/opencode" "$HOME_DIR/.config/opencode"
	mkdir -p "$HOME_DIR/.local/share/opencode" "$HOME_DIR/.config/opencode"
	cp -a "$STAGE/share/." "$HOME_DIR/.local/share/opencode/"
	cp -a "$STAGE/config/." "$HOME_DIR/.config/opencode/"
elif [[ -d "$STAGE/.local" ]]; then
	rm -rf "$HOME_DIR/.local/share/opencode" "$HOME_DIR/.config/opencode"
	cp -a "$STAGE/.local/share/opencode" "$HOME_DIR/.local/share/"
	cp -a "$STAGE/.config/opencode" "$HOME_DIR/.config/"
else
	echo "Archive layout not recognized." >&2
	exit 65
fi

chown -R "$UID_N:$GID_N" \
	"$HOME_DIR/.local/share/opencode" \
	"$HOME_DIR/.config/opencode"

echo "Restored. Session history is back in the cellar."
