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

**Docker Desktop WSL integration fails for rootcellar: `whoami: not
found` / `id: not found` / `groupadd: not found`**
- Structural, not fixable: integration probes exec `whoami`, `id`,
  `grep` with a classic FHS PATH. rootcellar is NixOS — `/usr/bin` holds
  only `env` (plus the `/bin/sh` wrapper), the real tools live in
  `/run/current-system/sw/bin`, and `wsl.exe -e` skips login shells, so
  that PATH never loads (`appendWindowsPath = false` by design).
- Fix: keep integration OFF for rootcellar — Settings → Resources →
  WSL integration, untick `rootcellar`. Native `docker.service` is the
  supported engine here; `cellar docker-doctor` says integration
  "overrides the native Docker Engine in the cellar"
  (`%APPDATA%\Docker\settings-store.json`: `IntegratedWslDistros`).

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
- Check with `cellar interop` (exits non-zero when missing). The config
  registers it declaratively (`wsl.interop.register = true`, applied by
  `systemd-binfmt` at every boot), so a deploy + reboot is the permanent fix.
- Immediate fix (needs root, applies now):
  `echo ':WSLInterop:M::MZ::/init:PF' | sudo tee /proc/sys/fs/binfmt_misc/register`
- Correlation seen 2026-09-28: the handler was wiped at 09:38 while
  Docker Desktop was starting (weston/docker-desktop mounts cycling in
  the journal). If it disappears again right after a Desktop start,
  re-register with the line above and note when it happened.
- The session notices: `cellar-kwin-poststart` preflights `cellar interop`
  and logs the fix line instead of maximization failing silently.

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

**Three borderless desktop windows piled on one screen, taskbar as a
separate window, wallpaper on one only (after `cellar deploy`)**
- The session came back half-alive: `try-restart kwin-headless` recycled
  plasmashell but the old `plasma-kwin_wayland` survived, so plasmashell
  attached to Weston (`WAYLAND_DISPLAY=wayland-0`) instead of the
  compositor and drew one desktop window per Weston output — WSLg
  exposes the whole Windows desktop to Weston (3 monitors here), and
  Weston's RAIL window positions are not mapped per-output, so they pile.
- Fix landed 2026-09-28 (`plasma-kwin_wayland` is now
  `PartOf=kwin-headless.service`): redeploy. Pre-fix recovery:
  `cellar close`, then `cellar ui`.
- Verify: `tr '\0' '\n' < /proc/$(pgrep -x plasma-plasmashell)/environ |
  grep WAYLAND_DISPLAY` must NOT print `wayland-0`. A healthy session
  shows **one** desktop window (KWin's nested backend exposes a single
  output), maximized, panel inside it.

**No desktop at all; session units fail with start-timeouts and zero
output; `plasma-kwin_wayland` "active" but no window ever maps**
- Check `pgrep -x kwin_wayland`: if only `kwin_wayland_wrapper` exists,
  the wrapper failed to exec the real compositor. It PATH-lookups
  `kwin_wayland` and ignores `QProcess::FailedToStart` — no log, the
  wrapper just sits holding the wayland-1 listener.
- Cause seen 2026-09-28: the unit became module-defined (the round-10
  `PartOf` drop-in), so NixOS stamped its default minimal PATH onto it
  and the wrapper could no longer find `kwin_wayland`.
- Fix (landed same day): `plasma-kwin_wayland` carries
  `path = [ config.system.path ]` in `modules/plasma.nix`, like dbus
  and plasma-plasmashell. Redeploy.
- Same symptom, second cause (also 2026-09-28): the compositor *does*
  exec but still never maps a window — KWin's nested backend connects
  out through `WAYLAND_DISPLAY`, and on a session restart that variable
  still holds our own socket name (`wayland-1`, left by a previous
  wrapper's `KUpdateLaunchEnvironmentJob`), so KWin reaches for its own
  listener and wedges. Check the compositor's environ:
  `tr '\0' '\n' < /proc/$(pgrep -x kwin_wayland)/environ | grep WAYLAND`
  — it must read `wayland-0` (Weston). Fix (landed same day): the unit
  pins `environment.WAYLAND_DISPLAY = "wayland-0"` in `modules/plasma.nix`.
  Redeploy.
- Third cause (seen 2026-09-29): the compositor unit never cycled. A
  bare `start` of `kwin-headless` while an older, wedged
  `plasma-kwin_wayland` is still active reuses it — `PartOf` only
  cascades when `kwin-headless` is *stopped while active*, so the stale
  compositor keeps the session dead and poststart reports `compositor
  window never appeared`. Check whether it actually restarted:
  `journalctl --user -u plasma-kwin_wayland --since today` — if there is
  no `Stopping`/`Starting KDE Window Manager` around the deploy time,
  stop it explicitly (`systemctl --user stop plasma-kwin_wayland`) and
  restart `kwin-headless`, or reboot the distro.
- Beware: redeploying does **not** clear this. `cellar deploy`'s user
  phase runs `try-restart kwin-headless`, which does nothing when
  that unit is already down — and when it *is* up, that stop is the
  only thing that takes the compositor down with it. Confirm at deploy
  time that `journalctl --user -u kwin-headless --since today` shows a
  `Stopping KDE Plasma 6 desktop` line; if not, do the manual stop
  above.

**`KWIN_COMPOSE=O2` (or blur/animation changes) have no effect**
- Under the nested Wayland backend KWin does not offer OpenGL — it wants
  linux-dmabuf plus a DRM device, and there is no `/dev/dri` in WSL — so
  it logs `Configured compositor not supported by Platform. Falling back
  to defaults` and runs software compositing: `qdbus org.kde.KWin
  /KWin supportInformation` reports `Compositing Type: QPainter`. The
  `O2` setting in `modules/plasma.nix` is therefore inert as of
  2026-09-29; QPainter is what runs.

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
