#!/usr/bin/env bash
# build-kernel.sh — build the RootCellar WSL2 kernel with the BORE scheduler.
#
# Clones Microsoft's WSL2 kernel (linux-msft-wsl-6.18.y), applies the vendored
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
PATCH_FILE="$REPO_ROOT/kernel/patches/bore-18-cachy.patch"
FIXUPS_FILE="$REPO_ROOT/kernel/patches/msft-6.18-fixups.patch"
FRAGMENT_FILE="$REPO_ROOT/kernel/bore.fragment"
KERNEL_BRANCH="linux-msft-wsl-6.18.y"
KERNEL_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/rootcellar/WSL2-Linux-Kernel"
INSTALL_TO="/mnt/c/Users/$(whoami)/wsl-kernel"
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

# Some environments (WSL images, dev containers) ship broken package-manager
# stubs. Detect by distro identity first, command existence second.
detect_pkg_manager() {
	local id_like id
	id="$(. /etc/os-release && echo "${ID:-unknown}")"
	id_like="$(. /etc/os-release && echo "${ID_LIKE:-unknown}")"
	case "$id $id_like" in
	*fedora* | *rhel*) echo dnf ;;
	*debian* | *ubuntu*) echo apt ;;
	*suse* | *SUSE*) echo zypper ;;
	*nixos*) echo nix ;;
	*)
		if command -v dnf >/dev/null 2>&1; then
			echo dnf
		elif command -v apt-get >/dev/null 2>&1; then
			echo apt
		elif command -v zypper >/dev/null 2>&1; then
			echo zypper
		else
			echo none
		fi
		;;
	esac
}

install_deps() {
	local pm
	pm="$(detect_pkg_manager)"
	case "$pm" in
	dnf)
		sudo dnf install -y make gcc flex bison dwarves openssl-devel elfutils-libelf-devel bc python3 cpio rsync
		;;
	apt)
		sudo apt-get update
		sudo apt-get install -y build-essential flex bison dwarves libssl-dev libelf-dev bc python3 pahole cpio rsync
		;;
	zypper)
		sudo zypper install -y make gcc flex bison dwarves libopenssl-devel libelf-devel bc python3 cpio rsync
		;;
	nix)
		log "nix detected — run this script via:  nix develop .#kernel -c ./kernel/build-kernel.sh"
		;;
	*)
		echo "Unsupported package manager. Install kernel build deps manually." >&2
		exit 69
		;;
	esac
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

# 2. Patch (skip if already applied — BORE must be present in BOTH the
#    Kconfig and fair.c; a partial application re-applies from scratch)
if ! grep -q "config SCHED_BORE" init/Kconfig ||
	! grep -q "sched_update_min_base_slice" kernel/sched/fair.c; then
	log "Applying BORE patch"
	git checkout -- kernel/sched/fair.c 2>/dev/null || true
	# Microsoft's tree drifts from CachyOS's base; known-good rejects are
	# resolved by the vendored fixups patch, applied right after.
	git apply --reject "$PATCH_FILE" 2>/dev/null || true
	if find . -name "*.rej" | grep -q .; then
		log "Applying MSFT tree fixups for rejected hunks"
		git apply "$FIXUPS_FILE"
	fi
	find . -name "*.rej" -delete
	grep -q "config SCHED_BORE" init/Kconfig &&
		grep -q "sched_update_min_base_slice" kernel/sched/fair.c || {
		echo "BORE patch did not apply cleanly; inspect kernel/sched/fair.c" >&2
		exit 65
	}
	# Commit the patched tree: keeps setlocalversion from appending a "+"
	# to the release string and makes rebuilds reproducible.
	if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
		git add -A
		git -c user.name="RootCellar Build" -c user.email="build@cellar.local" \
			commit -qm "RootCellar: BORE scheduler + msft fixups" || true
	fi
else
	log "BORE patch already applied"
fi

# 3. Config: WSL base + BORE fragment
# merge_config.sh writes to $KCONFIG_CONFIG (default .config). Point it at
# the exact file make reads next, or the merged fragment values (btrfs=y,
# LOCALVERSION, HZ) silently get dropped and the build uses the stock base.
# The backup lives outside the tree and the merge is committed afterwards:
# an untracked or modified file dirties the tree, and setlocalversion
# brands every kernelrelease with a trailing "+".
rm -f Microsoft/config-wsl.orig   # leftover from earlier script versions
cp Microsoft/config-wsl "${TMPDIR:-/tmp}/config-wsl.orig"
KCONFIG_CONFIG=Microsoft/config-wsl \
	"$PWD/scripts/kconfig/merge_config.sh" -m Microsoft/config-wsl "$FRAGMENT_FILE"
make KCONFIG_CONFIG=Microsoft/config-wsl olddefconfig
if ! git diff --quiet 2>/dev/null; then
	git add -A
	git -c user.name="RootCellar Build" -c user.email="build@cellar.local" \
		commit -qm "RootCellar: merge bore fragment into config-wsl" || true
fi

# 3b. Verify the merged config carries every fragment guarantee. A kernel
# missing one of these is silently broken for a whole class of WSL2
# runtimes (Docker Desktop's LinuxKit mounts ISO9660; the bare-attached
# VHD is btrfs; dockerd creates docker0 with the bridge/iptables stack),
# and the failure used to pass unnoticed. Fail loudly.
verify_fragment() {
	local cfg="Microsoft/config-wsl" fail=0
	check() {
		local sym="$1" pat="$2"
		if ! grep -qE "^${sym}=${pat}" "$cfg"; then
			echo "verify-fragment: ${sym} is not ${pat} in ${cfg}" >&2
			fail=1
		fi
	}
	check CONFIG_SCHED_BORE y
	check CONFIG_MIN_BASE_SLICE_NS 2000000
	check CONFIG_BTRFS_FS y
	check CONFIG_ISO9660_FS y
	check CONFIG_HZ_1000 y
	check CONFIG_LOCALVERSION '".*-rootcellar-bore"'
	check CONFIG_BRIDGE y
	check CONFIG_IP_NF_IPTABLES y
	check CONFIG_IP6_NF_IPTABLES y
	check CONFIG_NETFILTER_XT_TARGET_MASQUERADE y
	check CONFIG_IP_NF_TARGET_REJECT y
	check CONFIG_IP6_NF_TARGET_REJECT y
	check CONFIG_NFT_COMPAT y
	if (( fail )); then
		echo "verify-fragment: bore.fragment did not land — refusing to build a broken kernel." >&2
		echo "Inspect ${cfg} (grep -E 'CONFIG_(SCHED_BORE|BTRFS_FS|ISO9660_FS|BRIDGE|IP_NF_IPTABLES|NFT_COMPAT|IP_NF_TARGET_REJECT|HZ_1000|LOCALVERSION)=')." >&2
		exit 65
	fi
	log "Fragment verified: BORE, btrfs, ISO9660, bridge/iptables/REJECT, nft_compat, HZ_1000, LOCALVERSION all present"
}
verify_fragment

# 4. Build
log "Building kernel ($(nproc) jobs)"
make -j"$(nproc)" KCONFIG_CONFIG=Microsoft/config-wsl

# 4b. Verify the built image actually embeds the fragment config. The
# merged config file could still disagree with what got compiled; the
# bzImage is the ground truth. Fail loudly, do not install a broken kernel.
if [[ -x scripts/extract-ikconfig ]]; then
	log "Verifying built bzImage config (extract-ikconfig)"
	scripts/extract-ikconfig arch/x86/boot/bzImage >/dev/null 2>&1 || {
		echo "verify-fragment: extract-ikconfig failed — bzImage has no embedded config?" >&2
		exit 65
	}
	IMAGE_CFG="$(scripts/extract-ikconfig arch/x86/boot/bzImage)"
	for sym in CONFIG_SCHED_BORE CONFIG_BTRFS_FS CONFIG_ISO9660_FS CONFIG_HZ_1000 \
		CONFIG_BRIDGE CONFIG_IP_NF_IPTABLES CONFIG_IP6_NF_IPTABLES \
		CONFIG_NETFILTER_XT_TARGET_MASQUERADE CONFIG_IP_NF_TARGET_REJECT \
		CONFIG_IP6_NF_TARGET_REJECT CONFIG_NFT_COMPAT; do
		if ! grep -qE "^${sym}=y" <<<"$IMAGE_CFG"; then
			echo "verify-fragment: ${sym} is not =y in the built bzImage — refusing to install." >&2
			exit 65
		fi
	done
	if ! grep -qE '^CONFIG_LOCALVERSION=".*-rootcellar-bore"' <<<"$IMAGE_CFG"; then
		echo "verify-fragment: CONFIG_LOCALVERSION missing rootcellar-bore in the built bzImage." >&2
		exit 65
	fi
	log "Built image verified: BORE, btrfs, ISO9660, bridge/iptables/REJECT, nft_compat, HZ_1000, LOCALVERSION"
fi

# 5. Install
log "Installing bzImage to $INSTALL_TO"
mkdir -p "$INSTALL_TO"
# The running utility VM holds its own kernel image open on the Windows
# side, so an in-place overwrite fails with Permission denied while any
# WSL distro is up. Try direct, then after dropping a possibly read-only
# stale copy, and finally stage the file next to the target with the two
# PowerShell commands that complete the swap while the VM is down.
if ! cp arch/x86/boot/bzImage "$INSTALL_TO/bzImage" 2>/dev/null; then
	rm -f "$INSTALL_TO/bzImage" 2>/dev/null || true
	if ! cp arch/x86/boot/bzImage "$INSTALL_TO/bzImage" 2>/dev/null; then
		cp arch/x86/boot/bzImage "$INSTALL_TO/bzImage.staged"
		{
			echo "Could not replace $INSTALL_TO/bzImage: the running WSL VM holds its own kernel image."
			echo "The new kernel is staged at $INSTALL_TO/bzImage.staged — finish from PowerShell:"
			echo "  wsl --shutdown"
			# The $env: reference is PowerShell syntax and must reach the
			# user unexpanded — the single quotes are the point.
			# shellcheck disable=SC2016
			echo '  Copy-Item $env:USERPROFILE\wsl-kernel\bzImage.staged $env:USERPROFILE\wsl-kernel\bzImage -Force'
			echo "Then relaunch and verify: zgrep CONFIG_NFT_COMPAT /proc/config.gz   # -> =y"
		} >&2
		exit 65
	fi
fi
# A direct install only succeeds while the VM is down, so any staged file
# left by an earlier attempt is stale by now — clean it.
rm -f "$INSTALL_TO/bzImage.staged" 2>/dev/null || true

KERNEL_RELEASE="$(make -s KCONFIG_CONFIG=Microsoft/config-wsl kernelrelease)"
log "Done. kernelrelease = $KERNEL_RELEASE"
echo
# .wslconfig wants the Windows path, not the /mnt/c one.
if [[ "$INSTALL_TO" == /mnt/c/* ]]; then
	WIN_KERNEL="C:\\\\${INSTALL_TO#/mnt/c/}"   # C:\\Users/randy/wsl-kernel
	WIN_KERNEL="${WIN_KERNEL//\//\\\\}"        # C:\\Users\\randy\\wsl-kernel
	WIN_KERNEL="${WIN_KERNEL}\\\\bzImage"      # doubled, .wslconfig style
else
	WIN_KERNEL="${INSTALL_TO}/bzImage"
fi
echo "Next steps (Windows, PowerShell):"
echo "  1. Ensure .wslconfig contains:  kernel=$WIN_KERNEL"
echo "  2. Run:  wsl --shutdown"
echo "  3. Relaunch the distro and verify:  uname -r   # → ${KERNEL_RELEASE}"
