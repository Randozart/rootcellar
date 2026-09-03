#!/usr/bin/env bash
# build-kernel.sh — build the RootCellar WSL2 kernel with the BORE scheduler.
#
# Clones Microsoft's WSL2 kernel (linux-msft-wsl-6.6.y), applies the vendored
# CachyOS BORE patch, merges kernel/bore.fragment into the WSL config, builds,
# and installs the bzImage to the Windows side.
#
# The build tree defaults to ~/.cache/rootcellar (ext4). Building on /mnt/c
# (drvfs/9P) is 5-10x slower — pass --build-dir only with good reason.
#
# Usage:
#   ./build-kernel.sh [--deps] [--build-dir DIR]
#                     [--install-to /mnt/c/Users/<you>/wsl-kernel] [--clean]
#
# Idempotent per AGENTS.md: skips clone/patch/build steps that already succeeded.

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
PATCH_FILE="$REPO_ROOT/kernel/patches/bore-6.6-cachy.patch"
FRAGMENT_FILE="$REPO_ROOT/kernel/bore.fragment"
KERNEL_BRANCH="linux-msft-wsl-6.6.y"
KERNEL_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/rootcellar/WSL2-Linux-Kernel"
INSTALL_TO="/mnt/c/Users/randy/wsl-kernel"
WANT_DEPS=0

while [[ $# -gt 0 ]]; do
	case "$1" in
	--install-to)
		INSTALL_TO="$2"
		shift 2
		;;
	--build-dir)
		KERNEL_DIR="$2"
		shift 2
		;;
	--deps)
		WANT_DEPS=1
		shift
		;;
	--clean)
		echo "Removing $KERNEL_DIR"
		rm -rf "$KERNEL_DIR"
		exit 0
		;;
	*)
		echo "Unknown option: $1" >&2
		exit 64
		;;
	esac
done

log() { printf '\n\033[1;32m[rootcellar]\033[0m %s\n' "$*"; }

require_cmd() {
	command -v "$1" >/dev/null 2>&1 || {
		echo "Missing required command: $1" >&2
		echo "Re-run with --deps to install build dependencies (or use: nix develop .#kernel)" >&2
		exit 69
	}
}

install_deps() {
	if command -v apt-get >/dev/null 2>&1; then
		sudo apt-get update
		sudo apt-get install -y build-essential flex bison dwarves libssl-dev libelf-dev bc python3 pahole cpio qemu-utils rsync
	elif command -v dnf >/dev/null 2>&1; then
		sudo dnf install -y make gcc flex bison dwarves openssl-devel elfutils-libelf-devel bc python3 cpio rsync
	elif command -v zypper >/dev/null 2>&1; then
		sudo zypper install -y make gcc flex bison dwarves libopenssl-devel libelf-devel bc python3 cpio rsync
	elif command -v nix-shell >/dev/null 2>&1; then
		log "nix detected — run this script via:  nix develop .#kernel -c ./build-kernel.sh"
	else
		echo "Unsupported package manager. Install kernel build deps manually." >&2
		exit 69
	fi
}

if [[ ! -f "$PATCH_FILE" ]]; then
	echo "Vendored patch missing: $PATCH_FILE" >&2
	echo "Run kernel/check-upstream.sh --download first." >&2
	exit 66
fi

if [[ $WANT_DEPS -eq 1 ]]; then
	log "Installing build dependencies"
	install_deps
fi

for cmd in git make flex bison bc; do
	require_cmd "$cmd"
done

# 1. Source
if [[ ! -d "$KERNEL_DIR/.git" ]]; then
	log "Cloning WSL2 kernel ($KERNEL_BRANCH, shallow)"
	git clone --depth=1 --branch "$KERNEL_BRANCH" \
		https://github.com/microsoft/WSL2-Linux-Kernel.git "$KERNEL_DIR"
else
	log "Kernel source already present, skipping clone"
fi

cd "$KERNEL_DIR"

# 2. Patch (skip if already applied — BORE's Kconfig entry is the marker)
if ! grep -q "config SCHED_BORE" init/Kconfig; then
	log "Applying BORE patch"
	git apply --check "$PATCH_FILE"
	git apply "$PATCH_FILE"
else
	log "BORE patch already applied"
fi

# 3. Config: WSL base + BORE fragment
cp Microsoft/config-wsl Microsoft/config-wsl.orig
"$PWD/scripts/kconfig/merge_config.sh" -m Microsoft/config-wsl "$FRAGMENT_FILE"
make KCONFIG_CONFIG=Microsoft/config-wsl olddefconfig

# 4. Build
log "Building kernel ($(nproc) jobs)"
make -j"$(nproc)" KCONFIG_CONFIG=Microsoft/config-wsl

# 5. Install
log "Installing bzImage to $INSTALL_TO"
mkdir -p "$INSTALL_TO"
cp arch/x86/boot/bzImage "$INSTALL_TO/bzImage"

KERNEL_RELEASE="$(make -s KCONFIG_CONFIG=Microsoft/config-wsl kernelrelease)"
log "Done. kernelrelease = $KERNEL_RELEASE"
echo
echo "Next steps (Windows, PowerShell):"
echo "  1. Ensure .wslconfig contains:  kernel=$INSTALL_TO\\bzImage  (double backslashes)"
echo "  2. Run:  wsl --shutdown"
echo "  3. Relaunch the distro and verify:  uname -r   # → ${KERNEL_RELEASE}"
