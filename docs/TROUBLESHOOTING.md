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

**`zgrep CONFIG_ISO9660_FS /proc/config.gz` says `=m` (Docker Desktop broken)**
- The running kernel predates the ISO9660 built-in fix. Rebuild the kernel —
  the bore.fragment already carries `CONFIG_ISO9660_FS=y`, `build-kernel.sh`
  now refuses to install a kernel that lacks it:
  `nix develop .#kernel -c ./kernel/build-kernel.sh`, then `wsl --shutdown`,
  relaunch, verify `zgrep CONFIG_ISO9660_FS /proc/config.gz` shows `=y`.
- Same check applies after ANY bore.fragment edit: a kernel that silently
  dropped the fragment used to be possible; the verify step now catches it.

**`docker.service` fails: "Failed to create bridge docker0 via netlink:
operation not supported"**
- The running kernel ships the bridge/iptables stack as modules
  (`CONFIG_BRIDGE=m`, `IP_NF_IPTABLES=m`, `NETFILTER_XT_TARGET_MASQUERADE=m`)
  and a custom kernel has no loadable modules, so dockerd cannot create
  `docker0` or program NAT rules. `cellar docker-doctor` reports it.
- Fix: rebuild the kernel — the bore.fragment pins the whole set to `=y`
  and `build-kernel.sh` verifies `CONFIG_BRIDGE` and the iptables/NAT
  symbols before installing:
  `nix develop .#kernel -c ./kernel/build-kernel.sh`, then `wsl --shutdown`,
  relaunch, `sudo systemctl restart docker`.

**`docker.service` fails: "Extension MASQUERADE revision 0 not supported"
(iptables-nft: RULE_INSERT failed: No such file or directory)**
- The bridge came up (previous fix landed) but NAT did not: NixOS's
  `iptables` is the nftables backend, which realizes MASQUERADE through
  the compat layer — `CONFIG_NFT_COMPAT=m` is dead on a custom kernel.
  `cellar docker-doctor` reports it.
- Fix: rebuild the kernel (the bore.fragment pins `CONFIG_NFT_COMPAT=y`);
  same commands as above.

**Docker Desktop stuck on "Starting the Docker Engine…"**
- Primary signature (2026-09-23, Phase 0a):
  `Extension REJECT revision 0 not supported, missing kernel module?` →
  `RULE_APPEND failed … chain DOCKER-USER`. LinuxKit bootstrap programs
  a REJECT rule; the custom kernel shipped `IP_NF_TARGET_REJECT=m`.
  `cellar docker-doctor` reports the pin.
- Fix: rebuild the kernel (bore.fragment pins
  `CONFIG_IP_NF_TARGET_REJECT=y` / `CONFIG_IP6_NF_TARGET_REJECT=y`):
  `nix develop .#kernel -c ./kernel/build-kernel.sh`, then (PowerShell)
  `wsl --shutdown`, relaunch, verify
  `zgrep CONFIG_IP_NF_TARGET_REJECT /proc/config.gz` → `=y`.
  Quit Desktop fully (tray → Quit) before starting it again.
- Check order:
  1. REJECT pin above (this subsection).
  2. `zgrep CONFIG_ISO9660_FS /proc/config.gz` (Kernel & scheduler).
  3. Native engine conflict while testing Desktop:
     `sudo systemctl stop docker`.
  4. `sysctl kernel.sched_bore` A/B already cleared BORE as the cause
     (still stuck at `=0` on 2026-09-23) — do not re-litigate first.
  5. Logs: `%LOCALAPPDATA%\Docker\log\host\monitor.log`,
     `com.docker.backend.exe.log`; secondary older signature
     `no route to host 192.168.65.7:2376` often means dockerd already
     aborted above.
  6. Only if REJECT rebuild still fails: stock-kernel control
     (comment `kernel=` temporarily). **Never remove
     `networkingMode=mirrored`.**
- Upstream (do not re-diagnose from scratch): microsoft/WSL#40573,
  docker/for-win#15050, #14691 (mirrored × Desktop).

**`uname -r` shows `6.18.40.1-rootcellar-bore` without a trailing `+`**
- Expected since 2026-09-17. The `+` meant "built from a dirty tree" — the
  script's config backup and uncommitted merge left the tree unclean, and
  setlocalversion branded every release. The backup now lives outside the
  tree and the merge is committed, so the release string is honest.

**Installing the kernel fails: "cp: cannot create regular file
.../wsl-kernel/bzImage: Permission denied"**
- The running utility VM holds its own kernel image open; the copy can
  only succeed while no WSL distro is up. The build itself passed and is
  kept — `build-kernel.sh` stages it as `bzImage.staged` and prints the
  two PowerShell commands that finish the swap after `wsl --shutdown`.

## WSL interop

**Windows `.exe` calls fail with "Exec format error" — waybar window
controls (─ □ ⇱) dead**
- `windowctl.exe`, `powershell.exe`, `cmd.exe` all fail. The `WSLInterop`
  binfmt handler is missing from `/proc/sys/fs/binfmt_misc/` — WSL's
  boot-time registration was lost (fresh binfmt_misc mount, reconfig, or
  a sibling distro's activity).
- Check with `cellar interop`. The config registers it declaratively
  (`wsl.interop.register = true`, applied by `systemd-binfmt` at every
  boot), so a deploy + reboot is the permanent fix.
- Immediate fix (needs root, applies now):
  `echo ':WSLInterop:M::MZ::/init:PF' | sudo tee /proc/sys/fs/binfmt_misc/register`

## Boot / Nix

**Cellar boots to root, not your user**
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

**WSL warns at startup: "WSL2 Hostforwarding heeft geen effect bij
gespiegelde netwerken" (host forwarding has no effect with mirrored
networking)**
- Harmless but noisy: `localhostForwarding=true` in `.wslconfig` is a
  NAT-mode-only setting; mirrored networking ignores it.
- Fix: remove the line from `.wslconfig` (the RootCellar example ships
  without it), then `wsl --shutdown`.
- Anyone following NAT-era WSL guides will re-meet this warning.

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
