# Troubleshooting

Symptom-first, cellar-first.

## Kernel & scheduler

**`uname -r` does not show `rootcellar-bore`**
- `.wslconfig` `kernel=` path wrong (needs double backslashes) or file missing.
- `wsl --shutdown` not run after editing `.wslconfig`. Always manual, always after.

**Heavy load still freezes the terminal**
- `sysctl kernel.sched_bore` → if 0, the patch is not active (wrong kernel booted).
- If BORE is active, check `memory=` cap: host starvation looks identical to
  scheduler starvation. Task Manager → `Vmmem`.

**Patch no longer applies after `git pull` upstream**
- Kernel series moved (e.g. 6.6.122 → 6.6.123 with conflicting context lines).
  `kernel/check-upstream.sh --download` to re-vendor a matching patch;
  if CachyOS has not caught up yet, pin the previous kernel tag in
  `kernel/build-kernel.sh` until it does.

## Boot / Nix

**Cellar boots to root, not randy**
- NixOS-WSL normally handles this via `wsl.defaultUser`. If you rebuilt
  without `modules/base.nix`, add it back and rebuild.

**`nixos-rebuild switch` fails on a hash mismatch**
- `flake.lock` drifted against a moved branch: `nix flake update` and review.
- Unfree package refused: `nixpkgs.config.allowUnfree = true` is in base.nix;
  confirm you rebuilt with the flake, not a bare configuration.

**Rolled into a bad generation**
```bash
sudo nix-env --profile /nix/var/nix/profiles/system --rollback
sudo /nix/var/nix/profiles/system/bin/switch-to-configuration switch
```

## Desktop

**Login shell does not boot the deskbottom**
- `CELLAR_NO_AUTOSTART` set? Non-interactive context (`$TERM = dumb`, piped
  stdin) skips autostart by design. Run `cellar desktop` manually.

**`cellar app` says a key is missing but `cellar list` shows ok**
- `CELLAR_APPS` env points elsewhere; it should be `/etc/cellar/apps.toml`
  (set by `modules/deskbottom.nix`). Rebuild.

**Zellij layout did not change after editing cellar.kdl**
- Configs are baked into the Nix store — `nixos-rebuild switch`, then start
  a fresh session (`cellar kill` first, it asks).

**No sound**
- `wpctl status`: PipeWire must be running (WSLg provides the server).
- Windows side: check the host's default output device — WSLg mirrors it.

## Storage

**/mnt/projects not mounted after reboot**
- Task `RootCellar-AttachBtrfsVhd` runs at logon; did it? Get-ScheduledTask.
- fstab entry uses `nofail` on purpose: boot succeeds without the volume.
  After re-attach: `sudo mount -a`.

**Two disks, wrong one nearly formatted**
- `create-btrfs-vhd.ps1` asks before writing and aborts when ambiguous.
  Pass the device manually if you must, but `lsblk -f` first. Twice.

## Network

**VPN connected, cellar DNS dead**
- Confirm `.wslconfig` has `networkingMode=mirrored` + `dnsTunneling=true`.
- Legacy fallback: disable resolv.conf generation in wsl.conf and pin
  nameservers (last resort, pre-mirrored-era behavior).

**Windows can't reach a cellar dev server**
- Bind to 127.0.0.1? Bind 0.0.0.0 (firewalled) or rely on mirrored-mode
  localhost forwarding. Verify with `ss -lntp` inside the cellar.

**DNS breaks after sleep/resume or Wi-Fi switch**
- The `cellar-resolv` timer refreshes `/etc/resolv.conf` every 60 seconds.
  If it still fails, run: `sudo systemctl restart cellar-resolv.service`
- As a last resort: `wsl --shutdown` and relaunch.

**Localhost forwarding is flaky**
- In mirrored mode, `127.0.0.1` traffic may route via `loopback0` instead
  of `lo`. Fix: `sudo ip rule add pref 0 iif lo to 127.0.0.0/8 lookup local`
- If a service binds to `0.0.0.0` but is unreachable from Windows, try
  binding to `127.0.0.1` instead — the BPF interception is more reliable.
- Fallback: use `wsl hostname -I` to get the WSL IP, connect to that.

**Run `cellar netcheck` for a full diagnostic**
- Prints mirrored mode status, gateway, resolv.conf, DNS test, and
  localhost loopback test in one shot.

## Time

**Clock drifts after Windows sleeps**
```bash
sudo hwclock -s
```
Or run chrony (systemd makes this a one-module affair) if it happens daily.

## Escalation order (when all else fails)

1. `wsl --shutdown`, relaunch — clears 80% of weirdness.
2. `wsl --update` — WSL itself ships fixes constantly.
3. Roll back the Nix generation — undoes your last change surgically.
4. `wsl --export` as backup, then re-import to a new name — never
   `--unregister` without an export. Never.
