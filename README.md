# RootCellar

> *The room in the house without Windows, where root lives.*

A sovereign Linux environment for WSL2. It lives inside Windows, is technically
a subsystem, and could not care less — it boots into a full TUI desktop,
runs a BORE-scheduled custom kernel, and keeps your Windows host comfortable
while it does it.

```
Windows (the house)
└── WezTerm (the window you look through — ironically)
    └── rootcellar (WSL2, NixOS base)
        ├── Zellij .................... the window manager
        ├── cellar CLI ................ the start menu
        ├── yazi / btop / lazygit ..... the app suite
        ├── BORE kernel ............... the reflexes
        └── btrfs VHD ................. the cellar for projects
```

## Naming scheme

| Context | Name |
|---------|------|
| Repo | `rootcellar` |
| Project | RootCellar |
| Formal (releases, badges) | RootCellar OS |
| WSL distro | `rootcellar` |
| Hostname | `cellar` |
| Kernel release | `6.18.x-rootcellar-bore` |
| Shell prompt | `randy@cellar` |

## Features

- **BORE scheduler** — CachyOS-flavored Burst-Oriented Response Enhancer,
  vendored as a patch, built into the WSL2 kernel. Interactively responsive
  under heavy load. Patch watcher keeps it fresh (`kernel/check-upstream.sh`).
- **NixOS-WSL base** — the entire OS is one flake. Atomic generations, so every
  rebuild is a rollback point. Reproducible on any Windows box in one command.
- **Deskbottom Environment** — a desktop that lives at the bottom of the house:
  Zellij as WM, `cellar` as start menu, yazi/btop/lazygit as the app suite,
  kitty-graphics rendering through WezTerm, and real audio via WSLg PipeWire.
- **btrfs project volume** — a secondary VHD with `@` and `@projects`
  subvolumes: snapshots, reflink copies, zstd compression. Root stays ext4.
- **Windows host comfort** — `.wslconfig` with mirrored networking, memory
  reclaim, sparse VHDs, Defender exclusions, and Task Scheduler auto-mount.
- **Migration kit** — scripts to carry your opencode sessions and dotfiles
  out of an old distro and into the cellar.

## Quick start

From a fresh Windows machine, in order:

```powershell
# 1. Build the BORE kernel (from any existing WSL distro or inside rootcellar)
wsl -d <any-distro> -- ./kernel/build-kernel.sh

# 2. Point WSL at it + tune resources
Copy-Item windows\.wslconfig.example $env:USERPROFILE\.wslconfig
wsl --shutdown

# 3. Install NixOS-WSL (download nixos.wsl from NixOS-WSL releases, double-click)
wsl -d NixOS

# 4. Rebuild into the cellar
git clone <your-fork-url> /rootcellar && cd /rootcellar
sudo nixos-rebuild switch --flake .#rootcellar

# 5. Windows-side one-time setup (admin PowerShell)
windows\create-btrfs-vhd.ps1
windows\register-scheduled-tasks.ps1
windows\defender-exclusions.ps1

# 6. Set WezTerm as default terminal, default profile → rootcellar
# 7. Move in
migrate\import-opencode.sh cellar-backup.tar.gz
```

Launch your terminal. Zellij boots the deskbottom. Welcome to the cellar.

## Repository map

| Path | What lives there |
|------|------------------|
| `flake.nix` + `modules/` | The OS definition (NixOS-WSL) |
| `kernel/` | BORE kernel build pipeline, vendored patch, upstream watcher |
| `deskbottom/` | The Deskbottom Environment (Zellij, cellar CLI, app registry) |
| `windows/` | Windows-side configs and PowerShell (WezTerm, VHD, Defender) |
| `migrate/` | Export/import tooling for moving into the cellar |
| `docs/` | Deep dives: BORE, btrfs, GPU, migration, tuning, troubleshooting |

See `AGENTS.md` for the engineering standards enforced in this repo.

## Documentation

- [NixOS base & bootstrap](docs/NIX-BASE.md)
- [BORE scheduler](docs/BORE-SCHEDULER.md)
- [The Deskbottom Environment](docs/THE-DESKBOTTOM.md)
- [btrfs volume](docs/BTRFS-VOLUME.md)
- [GPU passthrough](docs/GPU-PASSTHROUGH.md)
- [Performance tuning](docs/PERFORMANCE-TUNING.md)
- [Migration](docs/MIGRATION.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)

## Acceptance tests

A cellar is "done" when:

```
uname -r                  → 6.18.x-rootcellar-bore
sysctl kernel.sched_bore  → 1
hostname                  → cellar
systemctl                 → systemd is PID 1
yazi in WezTerm           → image thumbnails render
mpv --vo=kitty            → video plays, sound works
/mnt/projects             → btrfs mounted, subvolumes @ and @projects
Windows reboot            → VHD re-attached by Task Scheduler
opencode                  → session history intact
fresh machine             → flake rebuild reproduces everything
```

## License

MIT — see [LICENSE](LICENSE).
