# PLAN — WSL interop: register WSLInterop declaratively

Status: approved · 2026-09-16

## Problem

The waybar window controls (─ minimize, □ maximize, ⇱ extend) stopped
working: they call `cellar minimize|maximize|extend` → `windowctl.exe`,
and `windowctl.exe` fails with `Exec format error` because the
`WSLInterop` binfmt handler is missing. No Windows `.exe` runs from the
cellar at all (`cmd.exe` fails the same way). `cellar close` still works
because it stops the systemd service directly and never touches
`windowctl`.

Root cause:
- WSL registers `WSLInterop` (`MZ` → `/init`) in `binfmt_misc` at distro
  boot. That registration was lost at the 2026-09-16 11:28 boot.
- `modules/base.nix` masks `systemd-binfmt.service` (a workaround for an
  old "it flushes interop" fear), so nothing ever re-registers it — a
  lost registration cannot self-heal.

The removal of the waymote/carbonyl stack is unrelated: the table was
already empty at 11:28, hours before those commits.

## Fix (chosen: Option A, recommended)

Declare the registration so systemd-binfmt re-adds it at every boot:

1. `modules/base.nix` — add `wsl.interop.register = true;` (NixOS-WSL's
   option → `boot.binfmt.registrations.WSLInterop`, magic `MZ`,
   interpreter `/init`, flags `PF`).
2. `modules/base.nix` — remove
   `systemd.units."systemd-binfmt.service".enable = false;` so the
   registration actually applies. Rationale for the old mask is inverted:
   masking is exactly why a lost WSL registration cannot recover. The
   "kills other distros" claim is per-namespace false — `binfmt_misc` is
   per mount namespace; what was observed was interop dying in the cellar
   itself, which declaring it now fixes.

## Diagnostic + docs

- `deskbottom/bin/cellar` — new `cellar interop`: reports whether
  `WSLInterop` is registered, the one-line immediate fix, and the other
  binfmt entries.
- `docs/TROUBLESHOOTING.md` — new section for the symptom and both fixes.

## Immediate fix (user runs, root)

```
echo ':WSLInterop:M::MZ::/init:PF' | sudo tee /proc/sys/fs/binfmt_misc/register
```

## Validation

`nix eval` of the toplevel drvPath · `nix flake check` · `bash -n` +
`shellcheck` on cellar.

## Commit

1. `fix(wsl): register WSLInterop declaratively so interop self-heals`
   (base.nix + cellar + TROUBLESHOOTING + this plan)