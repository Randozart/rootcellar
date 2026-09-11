# Update Manager

Keep every RootCellar PC in sync with a single command.

## Quick start

```bash
cellar update              # pull + show changes + confirm + deploy
cellar update --inputs     # also update nix flake inputs
cellar update --dry-run    # pull + report only, no rebuild
cellar update --kernel     # also check BORE patch drift
```

`cellar update` pulls from origin, shows you exactly what changed (git
log), asks for confirmation, then calls `cellar deploy` to sync and
rebuild. No surprises.

## Multi-PC workflow

Each Windows PC has its own git clone and `/opt/rootcellar` mirror. The
update workflow is:

**Primary PC** (runs flake updates + kernel builds):
```bash
cellar update --inputs --kernel
```

**Other PCs** (just pull and rebuild):
```bash
cellar update
```

The flake.lock is committed to git, so other PCs pick up the new
lock file on `git pull` without running `nix flake update` themselves.

## Kernel updates

The bzImage lives at `C:\Users\<you>\wsl-kernel\bzImage` on the Windows
side. If both PCs share the same Windows user, the path is already shared
via `/mnt/c`. After a kernel build on PC A, PC B picks it up on next
`wsl --shutdown` and relaunch.

If the PCs have different Windows users, copy the bzImage manually:
```bash
# On PC A (after kernel/build-kernel.sh):
cp /mnt/c/Users/<you>/wsl-kernel/bzImage /mnt/c/Users/<you>/other-pc-wsl-kernel/
```

## What `cellar update` does

1. **Pull**: `git pull --ff-only` — fails loudly if the branch has diverged
2. **Show**: `git log HEAD@{1}..HEAD --oneline` — lists every new commit
3. **Confirm**: prompts before proceeding
4. **Deploy**: calls `cellar deploy` (tar repo to /opt, rewrite flake inputs, nixos-rebuild)
5. **Kernel check** (if `--kernel`): runs `kernel/check-upstream.sh --quiet`

## What `cellar deploy` does (low-level)

`cellar deploy` is the sync primitive. It copies the repo to
`/opt/rootcellar`, rewrites `github:` URLs to local `path:` inputs (the
cellar cannot fetch from GitHub during rebuild), and runs
`nixos-rebuild switch`. Use `--no-rebuild` to skip the rebuild step.

```bash
cellar deploy              # sync + rebuild
cellar deploy --no-rebuild  # sync only
```
