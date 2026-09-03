#!/usr/bin/env bash
# check-upstream.sh — CachyOS-style BORE patch watcher.
#
# Compares the vendored patch (kernel/patches/, state in kernel/PATCH_VERSION)
# against upstream sources and reports — or downloads — newer patches.
#
# Sources, in priority order:
#   1. CachyOS kernel-patches (what the cellar runs)
#   2. firelzrd/bore-scheduler (upstream BORE)
#
# Usage:
#   ./check-upstream.sh                 # check and report drift
#   ./check-upstream.sh --download      # update vendored patch + PATCH_VERSION
#   ./check-upstream.sh --quiet         # exit code only (for CI/cron)

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_FILE="$SCRIPT_DIR/PATCH_VERSION"
PATCH_DIR="$SCRIPT_DIR/patches"
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

DOWNLOAD=0
QUIET=0
for arg in "$@"; do
	case "$arg" in
	--download) DOWNLOAD=1 ;;
	--quiet) QUIET=1 ;;
	*)
		echo "usage: $0 [--download] [--quiet]" >&2
		exit 64
		;;
	esac
done

say() { [[ $QUIET -eq 1 ]] || printf '%s\n' "$*"; }

[[ -f "$STATE_FILE" ]] || {
	echo "State file missing: $STATE_FILE" >&2
	exit 66
}

# shellcheck source=/dev/null
source "$STATE_FILE"

CACHY_URL="https://raw.githubusercontent.com/CachyOS/kernel-patches/master/${kernel_series}/sched/0001-bore-cachy.patch"

fetch_cachy() {
	curl -fsSL --max-time 30 -o "$TEMP_DIR/cachy.patch" "$CACHY_URL"
}

fetch_current() {
	if [[ -f "$PATCH_DIR/$(basename "${patch_file#patches/}")" ]]; then
		cp "$PATCH_DIR/$(basename "${patch_file#patches/}")" "$TEMP_DIR/current.patch"
	else
		cp "$PATCH_DIR/bore-${kernel_series}-cachy.patch" "$TEMP_DIR/current.patch"
	fi
}

# Returns 0 when the two files differ (i.e. upstream moved).
differs() { ! cmp -s "$1" "$2"; }

main() {
	local drifted=0

	fetch_current
	local current_sum
	current_sum="$(sha256sum "$TEMP_DIR/current.patch" | awk '{print $1}')"

	say "Vendored:  $current_sum  (${patch_file})"

	if fetch_cachy; then
		local cachy_sum
		cachy_sum="$(sha256sum "$TEMP_DIR/cachy.patch" | awk '{print $1}')"
		say "CachyOS:   $cachy_sum"
		if [[ "$cachy_sum" != "$current_sum" ]]; then
			drifted=1
			say "DRIFT: CachyOS has a newer BORE patch for kernel ${kernel_series}."
			[[ $DOWNLOAD -eq 1 ]] || {
				say "Re-run with --download to update the vendored patch."
			}
		else
			say "OK: vendored patch matches upstream CachyOS."
		fi
	else
		say "WARN: could not reach CachyOS upstream (offline?)."
		return 3
	fi

	if [[ $drifted -eq 1 && $DOWNLOAD -eq 1 ]]; then
		say "Updating vendored patch and PATCH_VERSION..."
		cp "$TEMP_DIR/cachy.patch" "$PATCH_DIR/bore-${kernel_series}-cachy.patch"
		local new_sum new_date
		new_sum="$(sha256sum "$TEMP_DIR/cachy.patch" | awk '{print $1}')"
		new_date="$(date +%F)"
		sed -i "s|^sha256=.*|sha256=$new_sum|; s|^updated=.*|updated=$new_date|" "$STATE_FILE"
		say "Updated. Rebuild the kernel:  kernel/build-kernel.sh"
	fi

	return $drifted
}

main
