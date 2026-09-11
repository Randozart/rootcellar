# Cozy configuration — cellar config, packages, and repo sync

The cellar is NixOS, but day-to-day configuration should not require
editing Nix. This is the cozy layer: a settings file, a package list,
and cellar verbs that edit, commit, push, and deploy in one step.

## The two cozy files

**`cellar.toml`** (repo root) — soft settings. Every key is optional;
missing file or key = the module defaults apply.

```toml
timezone = "Europe/Amsterdam"
locale = "en_US.UTF-8"
hostname = "cellar"

[docker]
enable = false

[cuda]
enable = false
# version = "12.8"

[webtop]
enable = true
```

`modules/settings.nix` bridges it into NixOS (`builtins.fromTOML`, no
IFD). Structural identity — `cellar.user`, `cellar.uid` — intentionally
stays in `flake.nix`: it is structural, not cozy (see
[PHILOSOPHY.md](PHILOSOPHY.md)).

**`modules/user-packages.list`** — one nixpkgs attribute path per line,
`#` comments. Appended to the static tool chest in `packages.nix`.
Unknown paths fail the eval loudly, pointing at `cellar check`.

## Commands

| Command | What it does |
|---------|--------------|
| `cellar config` | fzf menu: settings + feature toggles, then deploy |
| `cellar pkgs` | fzf package screen: search nixpkgs, multi-install, remove |
| `cellar search <q>` | search nixpkgs |
| `cellar check <pkg>...` | verify attribute paths resolve |
| `cellar add <pkg>...` | validate → append to the list → commit+push → deploy |
| `cellar remove <pkg>...` | drop from the list → commit+push → deploy |
| `cellar link [url]` | show/set the origin this cellar follows |
| `cellar save` | commit pending changes + push (local fallback) |

All flows that touch git require the repo to have `user.email` set.
Push failures degrade to a local commit with a notice — push from the
Windows side later; nothing is lost.

## Flows

**Install a package**: `cellar add fzf` (already there? try
`cellar search ripgrep` first). The change lands in
`user-packages.list`, gets committed as `cellar add: fzf`, pushed to
your origin, and deployed after a confirm.

**Move to a new machine**: `cellar link git@github.com:you/yourcellar`
clones your config, then deploys it. Your cellar follows your repo.

**Change a setting**: `cellar config` → Settings → pick → type the new
value → Apply. Flips are one keystroke in Features.

## Where things live

| File | Role |
|------|------|
| `cellar.toml` | soft settings (timezone, locale, hostname, toggles) |
| `modules/user-packages.list` | your packages |
| `modules/packages.nix` | the static tool chest (edit directly) |
| `flake.nix` | identity (`cellar.user`/`uid`) + module wiring |
