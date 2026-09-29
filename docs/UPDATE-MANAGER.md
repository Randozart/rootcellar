# Update Manager

Keep every RootCellar PC in sync with a single command.

## Quick start

```bash
cellar update              # integrate origin + base, show changes, confirm, deploy
cellar update --inputs     # also update nix flake inputs
cellar update --dry-run    # integrate + report only, no rebuild
cellar update --kernel     # also check BORE patch drift
```

`cellar update` integrates whatever your remotes have — `origin` (your
personal repo) first, then `upstream` (the shared base) — shows you
exactly what changed (git log), asks for confirmation, then calls
`cellar deploy` to sync and rebuild. A clone with no `upstream` remote
(base itself, or a machine not yet split) just pulls `origin` as
before. No surprises.

## Base and personal remotes

A split cellar tracks two remotes:

- **origin** — your personal repo (`rootcellar-home`). Machine-specific
  state lives here: `cellar.toml` values, `local.nix`, your commits.
  `cellar save` pushes here.
- **upstream** — the shared base repo (`rootcellar`). Core code, docs,
  and shared config. Updates flow from here.

```bash
cellar link                     # show both remotes + drift vs base
cellar link --upstream <url>    # add or re-point the base remote
```

On a split clone, `cellar update` fetches `origin` and `upstream`,
merges origin's branch first (other PCs' saves), then `upstream/main`
(base updates), pushes the integration commit back to `origin`, and
proceeds through show → confirm → deploy as described below.

Conflicts stop the merge. Nothing is ever auto-resolved: `cellar update`
prints the conflicted files and exits 1, leaving the merge in place.
Resolve, `git add <files> && git commit`, then re-run `cellar update`
(or `cellar deploy`).

> Run `cellar save` first if `cellar.toml` (or anything else) has
> uncommitted personal values — merges need a clean tree.

## Multi-PC workflow

Each Windows PC has its own git clone and `/opt/rootcellar` mirror. PCs
share state through your personal repo (`origin`); base updates arrive
through `upstream`. The update workflow is:

**Primary PC** (runs flake updates + kernel builds):
```bash
cellar update --inputs --kernel
```

**Other PCs** (just pull and rebuild):
```bash
cellar update
```

The flake.lock is committed to git, so other PCs pick up the new
lock file on `cellar update` without running `nix flake update`
themselves.

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

1. **Integrate**: fetch `origin` + `upstream`, then merge
   `origin/<branch>` followed by `upstream/main` (conflicts stop here,
   exit 1). Single-remote clones instead run `git pull --ff-only` —
   fails loudly if the branch has diverged
2. **Push**: the integration commit to `origin` (split clones, skipped
   on `--dry-run`; a failed push prints git's reason, nothing is lost)
3. **Show**: `git log <before>..<head> --oneline` — only what this run
   actually brought in
4. **Confirm**: prompts before proceeding
5. **Deploy**: calls `cellar deploy` (tar repo to /opt, rewrite flake inputs, nixos-rebuild)
6. **Kernel check** (if `--kernel`): runs `kernel/check-upstream.sh --quiet`

## What `cellar deploy` does (low-level)

`cellar deploy` is the sync primitive. It copies the repo to
`/opt/rootcellar`, rewrites `github:` URLs to local `path:` inputs (the
cellar cannot fetch from GitHub during rebuild), and runs
`nixos-rebuild switch`. Use `--no-rebuild` to skip the rebuild step.

```bash
cellar deploy              # sync + rebuild
cellar deploy --no-rebuild  # sync only
```
