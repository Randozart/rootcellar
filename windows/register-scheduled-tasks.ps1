<#
.SYNOPSIS
    Registers Task Scheduler entries that keep RootCellar plumbing alive.

.DESCRIPTION
    1. At logon: re-attach the btrfs VHD bare to WSL. The in-distro fstab
       (nofail) then mounts /mnt/projects automatically once the distro boots.
    2. Optional (-WithPatchWatch): daily task that runs kernel/check-upstream.sh
       inside the distro and prints a warning when the vendored BORE patch
       has drifted upstream.

    Idempotent: existing tasks with the same names are replaced.

.PARAMETER VhdPath
    The btrfs VHDX to re-attach at logon. Default: C:\wsl\rootcellar-btrfs.vhdx

.PARAMETER Distro
    WSL distro name. Default: RootCellar

.PARAMETER RepoPath
    Path of the repo inside the distro (used by the patch watcher).

.PARAMETER WithPatchWatch
    Also register the daily BORE patch check task.

.EXAMPLE
    .\register-scheduled-tasks.ps1 -WithPatchWatch
#>
#Requires -RunAsAdministrator
[CmdletBinding()]
param(
    [string]$VhdPath = "C:\wsl\rootcellar-btrfs.vhdx",
    [string]$Distro = "RootCellar",
    [string]$RepoPath = "/rootcellar",
    [switch]$WithPatchWatch
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 10)

function Install-Task {
    param(
        [string]$TaskName,
        [object]$Trigger,
        [object]$TaskAction
    )
    $existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Host "Replacing existing task: $TaskName"
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    }
    Register-ScheduledTask -TaskName $TaskName -Action $TaskAction -Trigger $Trigger -Principal $principal -Settings $settings | Out-Null
    Write-Host "Registered task: $TaskName"
}

# --- 1. At logon: re-attach the btrfs VHD -----------------------------------
$logonTrigger = New-ScheduledTaskTrigger -AtLogOn
$mountAction = New-ScheduledTaskAction -Execute 'wsl.exe' -Argument "--mount --vhd `"$VhdPath`" --bare"
Install-Task -TaskName 'RootCellar-AttachBtrfsVhd' -Trigger $logonTrigger -TaskAction $mountAction

# --- 2. Optional: daily BORE patch watcher ----------------------------------
if ($WithPatchWatch) {
    $dailyTrigger = New-ScheduledTaskTrigger -Daily -At '09:00'
    $inner = "cd $RepoPath 2>/dev/null && kernel/check-upstream.sh --quiet || echo 'BORE patch drift detected - run kernel/check-upstream.sh'"
    $watchAction = New-ScheduledTaskAction -Execute 'wsl.exe' -Argument "-d $Distro -u root -- bash -c `"$inner`""
    Install-Task -TaskName 'RootCellar-CheckBorePatch' -Trigger $dailyTrigger -TaskAction $watchAction
}

Write-Host ""
Write-Host "Task Scheduler setup complete. Changes take effect at next logon."
