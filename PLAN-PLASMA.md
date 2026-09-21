# PLAN-PLASMA — KDE Plasma 6 as a second session

## Goal

Plasma 6 (`cellar session plasma`) as a first-class sibling of the sway
deskbottom: same overlay/monitor controls, same theming discipline, no
crash loops. Attempt one proved the nesting works (startplasma-wayland
as a Wayland client of WSLg's Weston) but shipped raw: no overlay, no
theme, service crashes.

## Diagnosis (journal, 2026-09-18)

| Symptom | Cause | Fix |
|---|---|---|
| `plasma-powerdevil` + `plasma-polkit-agent` SIGABRT restart loops | power management has nothing to manage in a WSL2 VM; the polkit GUI agent aborts (KCrash: appFilePath nullptr) and GUI auth is never used here (sudo flows through the terminal) | mask both units |
| `plasma-baloorunner` runs | file indexer; pure CPU waste in WSL | mask |
| no themes on first boot | nothing seeded; `kdedefaults/package: device not open`; also bibata/papirus live in webtop.nix which plasma disables | first-run seed (see below) |
| no background | Plasma draws its own wallpaper; swww never runs there | seed Plasma's wallpaper with the original `/etc/cellar/sway/bg.jpg` |
| `cellar overlay` etc. dead | windowctl matches title substring `wlroots` only | match a title list (`wlroots`, `kwin`) |
| compositing heaviness | llvmpipe GL compositing | `KWIN_COMPOSE=Q` (QPainter software) |
| `[Common] CompositingMode=0` in kwinrc | guessed syntax, does nothing | drop it |

## Decisions

- **Mask, don't patch**: `systemd.user.units.<name>.enable = false` for
  the three offenders. WSL has no power stack, the cellar never shows a
  GUI polkit prompt, and indexing 8 GB of store paths is pointless.
- **Software compositing**: `KWIN_COMPOSE=Q` on the service env. This
  environment has no GPU (docs/CONVENIENT-DESKTOP.md); GL via llvmpipe
  is the expensive path.
- **First-run seed**, guarded on `~/.config/kdeglobals` being absent so
  we never fight the user's own System Settings choices:
  1. `~/.config/kdedefaults/package` = `org.kde.breezedark.desktop` —
     startplasma applies the look-and-feel natively on first boot
     (colors, window decorations, icons, splash) — no headless Qt
     tooling needed.
  2. `~/.config/kcminputrc` `[Mouse] cursorTheme=Bibata-Modern-Ice`.
  3. Wallpaper via `plasma-apply-wallpaperimage /etc/cellar/sway/bg.jpg`
     (guarded `|| true`; if the tool refuses to run headless, set the
     wallpaper once via right-click → Configure Desktop).
- **Wallpaper**: the long-standing default image
  (`assets/rootcellar-bg-girl-t-sat.jpg`), re-deployed to
  `/etc/cellar/sway/bg.jpg`. The three generated wallpapers stay on the
  sway side (swww rotation).
- **kwinrc snippet** keeps only `[Desktops] Number=5`. The
  `ModifierOnlyShortcuts` entry was dropped: Super never reaches the
  guest anyway (wslg#672).

## Live verification (post-deploy, user-side)

- `journalctl --user -u kwin-headless -u plasma-powerdevil -u
  plasma-polkit-agent --no-pager | tail` — no crash loops.
- Window title check for windowctl:
  `powershell.exe -c "Get-Process | ? { \$_.MainWindowTitle } | Select
  MainWindowTitle"` — confirm the KWin window matches one of the
  windowctl patterns, then `cellar overlay` / `cellar extend next`.

## Ricing round (2026-09-18, after attempt two)

Attempt two fixed the crashes but the visual layer still needed work.
Diagnosis: the first-run seed was an activation script guarded on
`kdeglobals` being absent — but the unthemed first boot had already
created it, so the seed silently no-op'd forever. Replaced by:

- **`org.rootcellar.desktop` look-and-feel** (`deskbottom/plasma/`):
  a RootCellar color scheme (cellar palette on the BreezeDark
  structure — schema-correct by construction) + L&F defaults cascading
  Bibata cursors and Papirus icons. No `[Wallpaper]` section in the
  L&F defaults, so a re-apply never resets the wallpaper.
- **`cellar-plasma-seed` user oneshot** (marker-guarded on
  `~/.config/cellar/plasma-seeded`): applies the L&F, cursor and the
  cellar wallpaper (`/etc/cellar/sway/bg.jpg`) explicitly, and writes
  `kdedefaults/package` for fresh installs. Marker-guard means it also
  migrates installs that already have an unthemed `kdeglobals`.
- **Fullscreen on launch**: `ExecStartPost` (`cellar-kwin-poststart`)
  polls `cellar maximize` for up to 30 s — the WSLg window maps
  asynchronously. Cosmetic failure never wedges the unit.
- **PipeWire spam**: `pipewire.socket` is now wanted by
  `default.target`; it was generated but never activated, and
  plasmashell's media monitor retried every 5 s.
- **Sound**: `environment.sessionVariables.PULSE_SERVER =
  unix:/mnt/wslg/PulseServer` — libpulse clients play through WSLg's
  RDP audio (verified the socket exists).

## Round 3 — debugging the rice (2026-09-18, journal forensics)

| Symptom | Root cause | Fix |
|---|---|---|
| `cellar help` / `--help` print nothing (exit 0) | `usage` awk-parses the header comments by position; the deployed file's line 2 is the `export WINDOWCTL=...` wrapper (non-comment), so awk's `{exit}` fires immediately | anchor awk on the `# cellar` header marker, skip everything before it |
| app launcher errors / empty, applets fail ("module not installed": activityswitcher, pager, folder) | plasmashell's unit env has no `/run/current-system/sw/share` in XDG_DATA_DIRS — the wrapped binary only prefixes its own store deps, so ksycoca sees no `applications/*.desktop` and plasma-desktop's QML modules are invisible | `systemd.user.managerEnvironment` sets `XDG_DATA_DIRS` for every user unit |
| crash dialogs after closing the session (plasmashell/kded6 SIGABRT loop, drkonqi popups) | teardown race: the units have `Restart=on-failure`; on session stop they die, restart with no compositor, Qt can't init a platform | drop-ins (`overrideStrategy = "asDropin"`): `PartOf=kwin-headless.service` + `Restart=no` — clean stop with the session |
| wallpaper + theme seed "never happened" | it never ran: `wantedBy = default.target` starts newly added units only when the user manager restarts, and the manager has been up since before the deploy | `cellar deploy-user` explicitly starts `cellar-plasma-seed` when the unit exists; each `plasma-apply-*` wrapped in `timeout 60` so a hang can never wedge the ordered kwin start and the marker always lands |
| "can't maximize even with cellar maximize" | maximize is a toggle, and the poststart had already maximized the window at launch — the manual command restored it | new `windowctl maximize-set` (idempotent); `cellar maximize` sets, `cellar overlay` stays the toggle |

Manual theming the user applied between sessions (plasma-apply-lookandfeel
→ org.rootcellar.desktop) confirmed the theme package resolves and looks
right; the seed still owns first-boot/migration duty.

## Round 4 — the login screen at launch (2026-09-18, evening)

The session started **locked**: kscreenlocker_greet engaged 4 s after
launch, PAM rejected the password, the desk was unusable.

- **Trigger**: WSLg's RDP layer cycles suspend/resume when the WSLg
  window loses focus (checking the deploy output in WezTerm was enough).
  kwin honours `LockOnResume` — default true — and locks on resume. The
  greeter's PAM stack (`kde:auth` + kwallet/fingerprint warnings) cannot
  authenticate reliably in WSL, so the lock was a one-way door.
- **Fix**: the nested session never locks. `kscreenlockerrc [Daemon]
  Autolock=false, LockOnResume=false, Timeout=0` — seeded write-once by
  the activation script (this install) and carried in the look-and-feel
  defaults (fresh installs).
- **Fullscreen, clarified**: the poststart DID maximize the window (the
  15 s `Starting... → Started` gap is the retry loop succeeding) — the
  lock screen was drawn over a maximized window. windowctl's "kwin"
  title match is confirmed live.
- **Wallpaper root cause**: `plasma-apply-wallpaperimage` is a live
  control tool — it D-Bus-calls plasmashell and *cannot* run before the
  session ("The name org.kde.plasmashell was not provided by any
  .service files"). Moved out of the pre-session seed into a new
  `cellar-plasma-wallpaper` oneshot: After kwin-headless, retries for
  plasmashell up to ~3 min, own marker. deploy-user starts it too.
- **Seed start mystery closed**: deploy-user's seed start was silently
  a no-op on its first run — the *invoking* cellar process was the old
  in-memory script. Self-heals on the next deploy; the manual start
  confirmed the seed itself works (cursor theme applied, marker written).
- **Known issue, deferred**: kwin's Xwayland fails
  (`/tmp/.X11-unix has no sticky bit`) when tmpfiles resets the socket
  dir after a deploy — the boot-time system fix doesn't re-run on
  switch. Non-fatal (wayland apps unaffected); X11 apps need
  `sudo systemctl start wslg-x11-sockets`.

## Status

- [x] Plan written
- [x] Masks + KWIN_COMPOSE=Q
- [x] First-run theming seed + bg.jpg restore
- [x] windowctl kwin match
- [x] Docs (CONVENIENT-DESKTOP)
- [x] Deployed and verified live (attempt two: no crash loops)
- [x] Ricing round verified live: theme applied, wallpaper set, window
      maximized at launch, journal free of pipewire spam
- [ ] Round 5 (black screen) verified live

## Round 5 — black screen: QML modules invisible (2026-09-18, late)

After the lock screen was disabled (round 4), the actual desktop was
visible — and it was **entirely black**. Plasmashell started but every
QML applet failed with `module "breeze" is not installed`. The desktop
containment (wallpaper/background), taskbar, clock, launcher, systray,
pager, and show-desktop all failed. Even the error renderer
(`AppletError.qml`) couldn't draw because it depends on
`Kirigami.Heading`.

- **Root cause**: the NixOS C-binary wrapper for `startplasma-wayland`
  sets `NIXPKGS_QT6_QML_IMPORT_PATH` (a NixOS-internal variable) but
  never copies it to `QML2_IMPORT_PATH` — the variable Qt 6's QML
  engine actually reads. Without it, **every KDE QML module is
  invisible**: `org.kde.breeze`, `org.kde.plasma.*`,
  `org.kde.private.desktopcontainment.folder`, etc.
- **Why `module "breeze"` specifically**: `qqc2-breeze-style` ships the
  `org.kde.breeze` QML module (at `lib/qt-6/qml/org/kde/breeze/`). It
  is NOT from `kdePackages.breeze` (which only provides the C++ style
  plugin `breeze6.so`). Kirigami.Heading (a dependency of every applet)
  does `import QtQuick.Controls; import org.kde.breeze` and fails.
- **Why lock screen masked it**: `kscreenlocker_greet` is a simpler QML
  app that doesn't depend on the broken modules — it rendered fine over
  a broken desktop.
- **Fix**: `cellar-kwin-env` — a thin shell wrapper that reads
  `NIXPKGS_QT6_QML_IMPORT_PATH` from the Nix C wrapper, exports it as
  `QML2_IMPORT_PATH`, then `exec`s the real `startplasma-wayland`.
  Also removed `QT_STYLE_OVERRIDE=breeze` from the service environment
  (Qt 6 doesn't have a style plugin named "breeze"; KDE's platform
  theme selects the style automatically via `XDG_CURRENT_DESKTOP=KDE`).
  Added `DISPLAY=:0` to the service environment for completeness.
- **Added `DISPLAY=:0`** to the kwin-headless service environment —
  the Nix C wrapper no longer sets it, and some Qt code paths still
  probe X11 even in Wayland mode.
