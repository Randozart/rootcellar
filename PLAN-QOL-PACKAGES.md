# PLAN — QoL: software center, package lanes, base tools

Status: approved · 2026-09-16

## Goal

Three things a tired brain can use:

1. **A visual software center** that installs packages either **local**
   (per-user `nix profile`, instant, no rebuild) or **frozen in**
   (declarative, git-backed, permanent) — without hand-editing config.
2. **Prepackaged base tools** (VSCodium, Docker, a dev set) that come
   with the base install.
3. A cleaner bar: drop the redundant start-menu button and the bottom
   clock.

## Concept

Every package is in one of three states:

| State | Where | Rebuild? | In git? |
|---|---|---|---|
| Available | nixpkgs | — | — |
| Local | `nix profile` (this user) | no | no |
| Frozen | `modules/user-packages.list` | yes (deploy) | yes |

The flow: **search → Install (local) → try it → Freeze in → Deploy.**

## Architecture

The GUI is a thin front-end over new `cellar` verbs; one source of truth,
CLI and GUI never diverge.

### Phase 1 — `cellar` verbs + deploy split

- `cellar use <pkg>...` / `cellar unuse <pkg>` — `nix profile install/remove
  nixpkgs#…` (local, no root). The `nixpkgs` registry is pinned to the
  system's nixpkgs source, so this hits the cache and needs no rebuild.
- `cellar freeze <pkg>` / `cellar unfreeze <pkg>` — edit
  `modules/user-packages.list` + `git_commit_push` (no root).
- `cellar profile --json` / `cellar frozen --json` / `cellar search --json
  <q>` — normalized JSON for the GUI.
- **Split `cmd_deploy`** so the root part runs from one `sudo`:
  - `cellar deploy-root` — git sync → `/opt` + `nixos-rebuild switch`
    (meant to run as root).
  - `cellar deploy-user` — `systemctl --user daemon-reload` + unit bounce.
  - `cellar deploy` — `sudo deploy-root` then `deploy-user` (unchanged).

### Phase 2 — the app (`pkgs/cellar-software-center/`)

Python 3 + PyGObject + GTK4/libadwaita, packaged with `wrapGAppsHook4`.

- **Views:** Featured (curated, instant) · Search (nixpkgs) · Local · Frozen.
- **Rows:** name, one-line description, state badge, actions
  **Install (local)** · **Freeze in** · **Remove local** · **Unfreeze**.
- **Search:** curated `featured.toml` for instant browsing + on-demand
  `nix search` (spinner; ~3s warm, ~44s cold once) with results cached in
  `~/.cache/cellar/`.
- **Deploy modal:** a libadwaita password dialog that collects **only the
  sudo password**, runs `sudo -S cellar deploy-root` (password on stdin,
  never logged), streams progress, then `cellar deploy-user`. Wrong
  password shows inline. A fallback link opens a floating foot window
  running `cellar deploy`.
- Freezing optionally removes the now-redundant local copy.
- Icons: the app's `.desktop` icon when installed, generic otherwise.

### Phase 3 — wiring + base tools + bar cleanup

- `cellar center` launches the app; a `.desktop` entry puts it in the grid.
- `Ctrl+Alt+S` → the GUI; the fuzzel `cellar store` stays as a quick path.
- `modules/devtools.nix` (default-on): `vscodium`, `nodejs`, `python3`,
  `go`, `gcc`, `gnumake`, `cmake`, `direnv`, `just`.
- `cellar.toml`: `[docker] enable = true` (daemon + compose at boot).
- Bar: drop `custom/start` (⊞/nwg-menu) from the top bar; drop the clock
  from the bottom bar.

## Validation

`nix build` the app · `bash -n` + `shellcheck` · JSONC parse · `nix eval`
toplevel + `nix flake check` · live test.

## Commits

1. `feat(desk): per-user profile + freeze verbs, split deploy for GUI sudo`
2. `feat(software-center): GTK4 app for local/frozen package management`
3. `feat(devtools): ship VSCodium + a base dev set; Docker on by default`
4. `desk(waybar): drop the nwg-menu button and the bottom clock`

## Notes / risks

- `nix profile` packages shadow system ones on `PATH` — intended for
  iteration; the frozen lane is the durable one.
- The deploy split touches an existing path; `cellar deploy` behavior is
  kept identical.
- Docker Desktop's WSL2 Integration still overrides the native daemon.
