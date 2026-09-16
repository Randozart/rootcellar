# PLAN — Nix build caching: trim dead weight, retain the store

Status: approved · 2026-09-16

## Problem

`nixos-rebuild` keeps getting slower. Diagnosis:

- Stock nixpkgs packages (firefox, chromium, sway, GNOME apps, the ~50
  tools) already substitute from `https://cache.nixos.org` — the pinned
  revs are Hydra-built.
- The slow builds are the **custom derivations**, all leftovers of the
  superseded waymote/noVNC browser-streaming architecture:
  1. `carbonyl` (`pkgs/carbonyl.nix`) — a Chromium build from source
     (hours). Installed in `systemPackages` but nothing launches it.
  2. `waymote` (`pkgs/waymote.nix`) + the `waymote-gateway` service —
     the zombie unit restart-looping in the journal; its `wlroots_0_18`
     patch override forces **sway + wlroots to compile from source**.
  3. Every nixpkgs input move re-hashes these custom derivations, so
     sway/wlroots rebuild from source again.

User decisions: remove carbonyl, remove waymote + wlroots patch, skip
Cachix.

## Step 1 — Remove the superseded streaming stack

| File | Change |
|---|---|
| `flake.nix` | drop `carbonyl` overlay, `waymote` overlay, `wlroots_0_18` override + comment block. Keep `nixpkgs-unstable` (opencode). Add input-hygiene comment. |
| `modules/webtop.nix` | remove `wayvnc`, `websockify`, `novnc`, `waymote`, `ffmpeg` from packages; delete the `wayvnc`, `websockify`, `waymote-gateway` services and the `ffmpeg-rtp` let binding. (`ffmpeg` stays via `packages.nix`.) |
| `modules/packages.nix` | remove `carbonyl` + the "Web (terminal)" section |
| `pkgs/carbonyl.nix` | delete |
| `pkgs/waymote.nix` | delete |
| `modules/base.nix` | reword the font comment that cites carbonyl (chromium remains) |
| `docs/THE-DESKBOTTOM.md` | drop carbonyl/waymote/browser-stream mentions |

Behavior note: the `wlroots_0_18` axis-source patch only affected
waymote's virtual pointer; the native WSLg mouse is unaffected.

## Step 2 — Nix store retention (`modules/base.nix`)

- `nix.settings.auto-optimise-store = true` — dedupe store paths.
- `nix.gc = { automatic = true; dates = "Mon 03:00"; options = "--max-freed 5G"; }`
  — collects old generations, never the current system closure.

## Validation

- `nix flake check`
- Prove sway no longer depends on the patched wlroots (grep the sway
  drv's dependency path for the override / confirm `wlroots_0_18` is
  stock).

## Commits

1. `refactor(desk): drop the superseded waymote/carbonyl/noVNC stack`
2. `chore(nix): auto-optimise the store and GC old generations`

User action after push: `cellar deploy`.