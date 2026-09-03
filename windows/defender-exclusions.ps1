<#
.SYNOPSIS
    Adds Windows Defender exclusions for RootCellar paths.

.DESCRIPTION
    Real-time scanning of the WSL virtual disks and project trees is the
    single largest tax on WSL2 file-heavy workloads. This excludes:
      - the RootCellar kernel install dir
      - the C:\wsl directory (VHDX + swap files)
      - the distro's home directory via the \\wsl.localhost UNC path

    Idempotent: existing exclusions are skipped.

.PARAMETER Distro
    WSL distro name. Default: RootCellar

.PARAMETER UserName
    Linux username whose home directory is excluded. Default: randy

.EXAMPLE
    .\defender-exclusions.ps1
#>
#Requires -RunAsAdministrator
[CmdletBinding()]
param(
    [string]$Distro = "RootCellar",
    [string]$UserName = "randy"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$paths = @(
    "$env:USERPROFILE\wsl-kernel",
    'C:\wsl',
    "\\wsl.localhost\$Distro\home\$UserName"
)

$existing = @(Get-MpPreference).ExclusionPath
foreach ($p in $paths) {
    if ($existing -contains $p) {
        Write-Host "Already excluded: $p"
    } else {
        Add-MpPreference -ExclusionPath $p
        Write-Host "Excluded:        $p"
    }
}

Write-Host ""
Write-Host "Defender exclusions in place. File-heavy workloads (git, npm, cargo)"
Write-Host "inside the cellar no longer pay the real-time scanning tax."
