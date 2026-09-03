# Performance Tuning

What actually moves the needle in WSL2, in order of impact.

## 1. Filesystem locality (the big one)

Code on `/mnt/c` pays a 9P network-protocol tax per syscall, plus Defender
scanning. Code on ext4/btrfs inside the cellar runs at near-native speed.

```
~/projects  →  symlink to /mnt/projects (btrfs volume)  — fast
/mnt/c/...  — interop only: exports, Windows-side tools, sharing out
```

`git status` and `npm install` on the wrong filesystem are the difference
between seconds and minutes. There is no tuning that fixes `/mnt/c`; there
is only moving the files.

## 2. Defender exclusions

Real-time scanning of the VHDX + project trees is the biggest *hidden* tax.
Run once (admin PowerShell):

```powershell
windows\defender-exclusions.ps1
```

Excludes `C:\wsl`, `%USERPROFILE%\wsl-kernel`, and
`\\wsl.localhost\rootcellar\home\randy`.

## 3. Resource boundaries (`.wslconfig`)

- `memory`: cap the VM so WSL and Windows stop fighting. Leave the host
  enough to stay responsive (8GB on a 16GB box).
- `processors`: leave 2–4 cores for Windows; builds stay fast, the host
  stays usable mid-compile.
- `swap`: small and audible. Thrashing you can hear is a bug you can find.
- `autoMemoryReclaim=gradual`: idle cache returns to Windows.
- `sparseVhd=true` + monthly compaction:

```powershell
# Inside WSL:    sudo fstrim /
wsl --shutdown
# In PowerShell: Optimize-VHD -Path <ext4.vhdx> -Mode Full   (Hyper-V module)
# or:            wsl --manage <distro> --set-sparse true
```

## 4. BORE kernel

See `docs/BORE-SCHEDULER.md`. Responsiveness under load is the headline;
the `sched_burst_penalty_scale` sysctl is the throttle between interactive
snappiness and build throughput.

## 5. inotify limits

Default 8192 watches dies quietly inside any monorepo. The cellar ships
524288 watches / 1024 instances via `modules/sysctl.nix` (applied by
systemd-sysctl at boot). Each watch costs ~1KB kernel memory worst-case.

## 6. Mirrored networking

`networkingMode=mirrored` + `dnsTunneling=true` removes the NAT layer:
localhost works both directions, VPNs stop eating DNS, and Windows-side
browsers hit WSL dev servers with zero forwarding rules.

## 7. VHDX placement

All distro I/O funnels through one `ext4.vhdx`. Keep it on the fastest NVMe
you have; if it lives on a slow secondary drive, *all* of the cellar is
slow. Move with `wsl --export` → `wsl --import` to a new path.

## Measure, then tune

```bash
htop            # CPU/mem live
free -h         # did the memory cap apply?
iotop           # who is hammering I/O
ncdu /          # what is eating the disk
btop            # everything, pretty
```

Windows side: Task Manager → `Vmmem` is the cellar's real footprint.
