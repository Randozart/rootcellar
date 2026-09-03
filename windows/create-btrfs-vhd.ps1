<#
.SYNOPSIS
    Creates and attaches the RootCellar btrfs project volume (secondary VHD).

.DESCRIPTION
    Creates a dynamic VHDX, attaches it bare to WSL, formats it as btrfs
    inside the rootcellar distro, creates the @ and @projects subvolumes,
    and adds a nofail fstab entry mounting @projects at /mnt/projects.
    Idempotent: an existing VHDX is reused; an existing fstab UUID is skipped.

    The bare attach does NOT survive a Windows reboot by itself — run
    register-scheduled-tasks.ps1 to automate re-attachment at logon.

.PARAMETER VhdPath
    Windows path for the VHDX. Default: C:\wsl\rootcellar-btrfs.vhdx

.PARAMETER SizeGB
    Virtual size in GB. btrfs grows on demand; the VHDX is dynamic.
    Default: 128

.PARAMETER Distro
    WSL distro name. Default: rootcellar

.EXAMPLE
    .\create-btrfs-vhd.ps1
#>
#Requires -RunAsAdministrator
[CmdletBinding()]
param(
    [string]$VhdPath = "C:\wsl\rootcellar-btrfs.vhdx",
    [int]$SizeGB = 128,
    [string]$Distro = "rootcellar"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-Command {
    param([string]$Name, [string]$Hint)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command '$Name' not found. $Hint"
    }
}

Assert-Command 'wsl' "Install WSL first: wsl --install --no-distribution"

# --- 1. Create the VHDX (skip if it already exists) -------------------------
if (Test-Path $VhdPath) {
    Write-Host "VHDX already exists, reusing: $VhdPath"
} else {
    $dir = Split-Path $VhdPath -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }

    if (Get-Command New-VHD -ErrorAction SilentlyContinue) {
        New-VHD -Path $VhdPath -Dynamic -SizeBytes ($SizeGB * 1GB) | Out-Null
        Write-Host "Created dynamic VHDX: $VhdPath ($SizeGB GB virtual)"
    } else {
        throw "New-VHD not available (Hyper-V PowerShell module missing). " +
              "Enable 'Hyper-V' features or create the VHDX with Disk Management, then re-run."
    }
}

# --- 2. Attach bare to WSL ---------------------------------------------------
wsl --mount --vhd $VhdPath --bare
if ($LASTEXITCODE -ne 0) { throw "wsl --mount failed with exit code $LASTEXITCODE" }
Write-Host "Attached bare to WSL."

# --- 3. Format + subvolumes + fstab inside the distro -----------------------
$setup = @'
set -Eeuo pipefail

CANDIDATES="$(lsblk -dpno NAME,TYPE,FSTYPE | awk "\$2==\"disk\" && (\$3==\"\" || \$3==\"xfs\" || \$3==\"btrfs\" || \$3==\"ext4\") {print \$1}")"
TARGET=""
for dev in $CANDIDATES; do
    if ! findmnt -S "$dev" >/dev/null 2>&1 && [ "$(lsblk -no FSTYPE "$dev" | tr -d "[:space:]")" = "" ]; then
        TARGET="$dev"
        break
    fi
done
if [ -z "$TARGET" ]; then
    echo "No unformatted candidate disk found. Was this volume already set up?" >&2
    exit 3
fi

read -r -p "Format $TARGET as btrfs (ALL DATA ON IT IS ERASED)? [y/N] " reply
case "$reply" in
    y|Y) ;;
    *) echo "Aborted."; exit 1 ;;
esac

mkfs.btrfs -L cellar "$TARGET"

MNT=$(mktemp -d)
mount "$TARGET" "$MNT"
btrfs subvolume create "$MNT/@"        >/dev/null
btrfs subvolume create "$MNT/@projects" >/dev/null

UUID="$(blkid -s UUID -o value "$TARGET")"
umount "$MNT"; rmdir "$MNT"

if ! grep -q "$UUID" /etc/fstab; then
    echo "UUID=$UUID  /mnt/projects  btrfs  defaults,nofail,compress=zstd,subvol=@projects  0 0" >> /etc/fstab
    echo "Added /etc/fstab entry for /mnt/projects"
fi

mkdir -p /mnt/projects
mount -a
echo "Ready: $(findmnt -n -o SOURCE /mnt/projects) -> /mnt/projects"
'@

wsl -d $Distro -u root -- bash -c $setup
if ($LASTEXITCODE -ne 0) { throw "In-distro setup failed (exit $LASTEXITCODE). Is the '$Distro' distro installed?" }

Write-Host ""
Write-Host "Done. /mnt/projects is now btrfs with @ and @projects subvolumes."
Write-Host "NOTE: re-attach after Windows reboot is automated by register-scheduled-tasks.ps1."
