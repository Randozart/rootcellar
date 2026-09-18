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

## Status

- [x] Plan written
- [x] Masks + KWIN_COMPOSE=Q
- [x] First-run theming seed + bg.jpg restore
- [x] windowctl kwin match
- [x] Docs (CONVENIENT-DESKTOP)
- [x] Deployed and verified live (attempt two: no crash loops)
- [ ] Ricing round verified live: theme applied, wallpaper set, window
      maximized at launch, journal free of pipewire spam
