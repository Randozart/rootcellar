#!/usr/bin/env bash
# export-home.sh — pack the small, precious things: SSH keys, git config,
# shell rc files, opencode config. NOT a full home backup — use
# `wsl --export` for disaster recovery of an entire distro.
#
# Usage:
#   ./export-home.sh [output-dir]     # default: /mnt/c/Users/<you>

set -Eeuo pipefail

USER_NAME="${SUDO_USER:-$USER}"
HOME_DIR="$(getent passwd "$USER_NAME" | cut -d: -f6)"
OUTPUT_DIR="${1:-/mnt/c/Users/$(whoami)}"
STAMP="$(date +%F)"
ARCHIVE="$OUTPUT_DIR/cellar-home-backup-$STAMP.tar.gz"

cd "$HOME_DIR"

ITEMS=()
for candidate in \
	.ssh .gitconfig .gitignore_global \
	.bashrc .zshrc .profile .tmux.conf \
	.config/opencode/opencode.jsonc \
	.config/starship.toml \
	.config/zellij; do
	[[ -e "$candidate" ]] && ITEMS+=("$candidate")
done

if [[ ${#ITEMS[@]} -eq 0 ]]; then
	echo "Nothing worth packing found in $HOME_DIR" >&2
	exit 66
fi

printf 'Packing:\n'
printf '  %s\n' "${ITEMS[@]}"

tar -czf "$ARCHIVE" "${ITEMS[@]}"

SUMMARY="$(du -h "$ARCHIVE" | cut -f1)"
echo "Wrote: $ARCHIVE ($SUMMARY)"
echo "Reminder: this archive contains private keys. Store it accordingly."
