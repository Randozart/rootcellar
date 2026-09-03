# Migration Guide (into the cellar)

Two paths: **selective** (recommended — fresh cellar, carry your data) or
**full clone** (`wsl --export`/`--import`, carries everything including the
clutter).

## Path A: Selective (recommended)

### 1. From the old distro (e.g. FedoraLinux-44)

```bash
# opencode sessions (2.7GB of history) + config:
migrate/export-opencode.sh                 # → /mnt/c/Users/randy/opencode-backup-<date>.tar.gz

# SSH keys, git config, shell dotfiles:
migrate/export-home.sh                     # → cellar-home-backup-<date>.tar.gz
```

Both scripts exclude junk, verify source paths exist, and write to the
Windows side. The home backup contains **private keys** — treat the archive
accordingly.

### 2. Boot the cellar

Follow `docs/NIX-BASE.md` (kernel → `.wslconfig` → nixos.wsl → flake switch).

### 3. Into the cellar

```bash
sudo migrate/import-opencode.sh /mnt/c/Users/randy/opencode-backup-<date>.tar.gz

# Home dotfiles:
tar -xzf /mnt/c/Users/randy/cellar-home-backup-<date>.tar.gz -C ~
chmod 700 ~/.ssh && chmod 600 ~/.ssh/* 2>/dev/null || true
```

The import script fixes ownership to uid 1000 (`randy` in the cellar matches
the old distro's uid, so file modes survive intact).

### 4. Move the code

Clone repositories fresh into `/mnt/projects` (btrfs) — or bulk-move from
the old distro's home if they are not pushed anywhere:

```bash
# Old distro:
tar -cf - -C ~/projects . | wsl -d rootcellar -u randy -- tar -xf - -C /mnt/projects
```

## Path B: Full clone (disaster recovery style)

```powershell
wsl --shutdown
wsl --export FedoraLinux-44 D:\backups\fedora.tar
mkdir C:\wsl\imported
wsl --import fedora-clone C:\wsl\imported D:\backups\fedora.tar
wsl -d fedora-clone
```

### The root-user gotcha

After **any** `wsl --import`, the distro logs in as **root**. Fix it inside
the distro:

```bash
# /etc/wsl.conf
[user]
default = randy
```

then `wsl --shutdown` and relaunch. (NixOS-WSL sets this via
`wsl.defaultUser` in the flake, so a fresh cellar does not hit this.)

## What does NOT travel automatically

| Item | Where it lives | How to move |
|------|----------------|-------------|
| `.wslconfig` | Windows user profile | copy the file |
| WSL distro registration | registry | `wsl --import` (Path B) |
| `/mnt/c` files | Windows | already there |
| Docker images (in-distro) | inside distro | included in Path B; otherwise re-pull |
| opencode session history | `~/.local/share/opencode` | Path A scripts |
| SSH/GPG keys | `~/.ssh`, `~/.gnupg` | Path A `export-home.sh` |

## After moving in — checklist

```
[ ] uname -r shows rootcellar-bore
[ ] opencode resumes session history (opencode → list sessions)
[ ] ssh -T git@github.com answers as you
[ ] git config --global user.name/email intact
[ ] /mnt/projects mounted (findmnt /mnt/projects)
[ ] cellar app launches apps from the start menu
```

Keep the export archives for a week after the move. Delete after the first
successful week in the cellar. Archives with private keys go to encrypted
storage or the shredder, not the Downloads folder.
