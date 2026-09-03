# AGENTS.md — Engineering Standards for RootCellar

This repository defines an operating environment. Sloppy code in a repo like
this becomes someone's broken Tuesday. These standards are **strict and
non-negotiable**. Any agent or contributor working here follows them.

## Golden rules

1. **Idempotent or dead.** Every script must be safely re-runnable. Detect
   existing state, skip completed work, never double-apply.
2. **Ask before destroying.** Any destructive operation (delete, overwrite,
   unmount, `wsl --unregister`) requires an explicit confirmation prompt with
   the exact target printed. No `-y`-by-default.
3. **No secrets, ever.** No keys, tokens, IPs of private infra, or client data
   in code, config, docs, or commit history. If it leaked, rotate first, clean
   history second.
4. **Small diffs.** One logical change per commit. Do not reformat code you
   are not otherwise touching.
5. **Read before write.** Understand surrounding conventions before editing.
   This repo has strong opinions; match them, don't fight them.
6. **Validate everything you touch** (see Validation Matrix below) before
   declaring a task complete.

## Language standards

### Bash (all `*.sh`)

- `#!/usr/bin/env bash` shebang, **always** `set -Eeuo pipefail` after it.
- Must pass `shellcheck` with zero warnings. No `shellcheck disable` without
  a justification comment explaining why the warning is wrong.
- Quote every variable expansion. Prefer `"$var"` over `$var` without exception.
- Use `$(...)` not backticks. Use `[[ ]]` not `[ ]` in bash.
- Long options preferred for readability in scripts (`--depth=1`).
- Functions over copy-paste; shared helpers live in a `lib/` next to the
  scripts that use them.
- Cleanup with `trap` when creating temp files or changing system state.
- First-run detection: check for markers (`command -v`, file existence,
  version compare) before installing/configuring.

### Nix (all `*.nix`, `flake.nix`)

- Formatted with `nixfmt`. `nix flake check` must pass.
- No import-from-derivation (IFD) unless documented with a written
  justification in a comment directly above.
- Prefer stable `nixpkgs` input; `unstable` only per-option with a comment.
- One module = one concern. Modules under `modules/` are additive and use
  `lib.mkDefault` / `mkIf` so they compose and can be overridden.
- Options declared in a module belong to that module. Shared options go in
  `modules/base.nix` under the `cellar.*` namespace.
- `system.stateVersion` is frozen. Never bump it as part of other work.

### Lua (`windows/wezterm.lua`)

- Formatted with StyLua (4-space indent, standard style).
- Config must work on a fresh WezTerm install; degrade gracefully if fonts
  are missing (fallback list, no hard failure).

### PowerShell (all `*.ps1`)

- `#Requires` directives at top where privileges/versions matter.
- Must pass `PSScriptAnalyzer` with zero errors.
- `Set-StrictMode -Version Latest` and `$ErrorActionPreference = 'Stop'`.
- Approved verbs in function names. Comment-based help on every function.

### TOML / YAML / KDL / INI

- Preserve existing key order when editing. Add new keys adjacent to related
  ones, not appended at random.

## Validation matrix

| You changed… | You must run… |
|---|---|
| any `*.sh` | `bash -n` + `shellcheck <file>` |
| `flake.nix` / `modules/*.nix` | `nix flake check` (or state clearly that Nix was unavailable) |
| `windows/*.ps1` | `PSScriptAnalyzer` (or state clearly it was unavailable) |
| `deskbottom/zellij/*` | syntax review against Zellij KDL docs; no guessing syntax |
| docs | re-read for factual drift against the code |
| `kernel/patches/` | update `kernel/PATCH_VERSION` (sha256 + date) in the same commit |

If a validator is unavailable in your environment, **say so explicitly** in
your summary instead of claiming success.

## Repository conventions

- **File placement** follows the map in `README.md`. New categories get a
  README-paragraph before they get files.
- **Vendored artifacts** (`kernel/patches/`) are updated only by
  `kernel/check-upstream.sh --download` or a human who updates
  `kernel/PATCH_VERSION` atomically with the patch change.
- **Commits** follow Conventional Commits:
  `type(scope): summary` — types: `feat`, `fix`, `docs`, `refactor`,
  `chore`, `kernel`, `desk`, `win`. Scope optional. Imperative mood.
  Example: `kernel(bore): vendor cachy patch 6.6 refresh`
- **Branches**: `main` is always deployable. Feature branches named
  `type/short-description`.
- **Docs live with behavior.** If a script's behavior changes, the relevant
  `docs/*.md` changes in the same PR. Stale docs are bugs.
- **No AI slop.** No emoji in code or commit messages. No filler comments
  restating the code. Comments explain *why*, never *what*, except where a
  config file doubles as documentation (`.wslconfig.example`, fragments) —
  there, comments are the feature.

## Environment notes

- The repo may be checked out on `/mnt/c` (drvfs). Do not add tooling that
  requires POSIX permissions/symlinks on that path without a fallback.
- Windows-side scripts assume admin where stated. Linux-side scripts assume
  the distro they run in may be *any* distro (bootstrap phase) — dependency
  installation must detect apt/dnf/zypper/nix and fail loudly otherwise.
- `wsl --shutdown` is disruptive. Scripts never call it unprompted; they print
  the instruction instead.

## When in doubt

Prefer boring and reversible over clever. This repo's whole point is a system
that comes back up smiling. If your change makes that less true, redesign it.
