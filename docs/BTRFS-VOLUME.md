# btrfs Project Volume

The cellar's storage has two layers:

- **Root filesystem**: ext4 (hardcoded by WSL; fighting it means unofficial
  forks — not worth the fragility).
- **Projects volume**: a *secondary* btrfs VHD mounted at `/mnt/projects`.
  This is where snapshots, reflink copies, and compression earn their keep.

## Layout

```
C:\wsl\rootcellar-btrfs.vhdx        (dynamic VHDX, grows on demand)
└── btrfs (label: cellar)
    ├── @                            (subvolume root, spare)
    └── @projects  →  /mnt/projects  (your work lives here)
```

Mount options in `/etc/fstab`: `defaults,nofail,compress=zstd,subvol=@projects`

## Setup (one-time, admin PowerShell)

```powershell
windows\create-btrfs-vhd.ps1              # create + format + subvolumes + fstab
windows\register-scheduled-tasks.ps1      # re-attach after Windows reboot
```

`create-btrfs-vhd.ps1` prompts before formatting (it refuses to guess when
the candidate disk is ambiguous). `wsl --mount --vhd ... --bare` does not
survive a Windows reboot — the logon Task Scheduler entry re-attaches it,
and the `nofail` fstab entry mounts it when the distro boots.

## Snapshots

```bash
# Snapshot the projects volume before a risky rebase:
sudo btrfs subvolume snapshot -r /mnt/projects /mnt/projects/.snapshots/$(date +%F-%H%M)

# List / inspect:
sudo btrfs subvolume list /mnt/projects
sudo btrfs subvolume show /mnt/projects
```

Snapshots are cheap (COW metadata only). Rotate them with a cron/systemd
timer; delete with `btrfs subvolume delete`.

## Reflink copies

Within the volume, `cp` is instant and space-free until files diverge:

```bash
cd /mnt/projects
cp --reflink=always -r big-project big-project-experiment
```

This is what tools like [vibe](https://vibe.kite.dev/recipes/wsl2-btrfs/)
detect automatically. Reflink does **not** work from ext4 to btrfs or across
VHDs — source and destination must both live on the cellar volume.

## Compression

`compress=zstd` shrinks text-heavy trees (node_modules, rust target dirs)
transparently, and the VHDX stays smaller on the Windows side. Check savings:

```bash
sudo btrfs filesystem df /mnt/projects
compsize /mnt/projects   # optional: per-algorithm breakdown
```

## Notes & gotchas

- Keep `.snapshots/` excluded from editor watchers and backups of the volume.
- `wsl --shutdown` while the VHD is mounted is safe; WSL unmounts cleanly.
- Do **not** try `btrfs-convert` on the ext4 root — the converted root will
  not boot in WSL.
- Explorer can browse `/mnt/projects` via
  `\\wsl.localhost\rootcellar\mnt\projects` (9P; fine for peeking, slow for
  heavy I/O — do the heavy I/O from inside the cellar).
