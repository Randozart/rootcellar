# PLAN — HyprDesk: Hyprland as the cellar's window manager

Status: in progress · 2026-09-11
Predecessor: PLAN-2026-09-11.md (desktop tier via labwc/XFCE — superseded by this plan)

## Goal

`cellar overlay` gives a fullscreen, native-resolution Hyprland desktop on the
Windows side, with the RootCellar Zellij session docked inside it. The desktop
becomes a real window manager for the cellar: launch browsers and GUI apps,
work in tiled terminals that share the same session as the Windows-side
WezTerm. Windows shrinks to a boot loader and a display driver.

## User requirements (non-negotiable)

1. **Manual boot.** Nothing autostarts the desktop at login. The Hyprland
   service runs headless (invisible, harmless), but the *mode* begins only
   when the user opens a viewer: `cellar overlay` or the Carbonyl pane.
2. **Escape hatch.** There is always a way back to Windows:
   - `Alt+F4` closes the kiosk overlay (Windows side, always available)
   - `Super+Shift+E` exits Hyprland (session teardown inside the desktop)
   - The WezTerm terminal and `cellar` commands are unaffected either way
3. **All screens eventually.** Phase 1 = single overlay window; Phase 2 =
   one headless output + one wayvnc port + one kiosk per external monitor,
   forming a true multi-monitor Hyprland desktop.

## Architecture

```
Hyprland (headless-first; AQ_BACKEND_HEADLESS mandatory, DRM/Wayland optional)
 ├─ HEADLESS-1 output, 1920x1080            (hyprctl output create headless)
 │   └─ wayvnc 127.0.0.1:5900 → websockify :6080 → noVNC
 │        ├─ Carbonyl pane                  (in-terminal view, as today)
 │        └─ Edge/Chrome kiosk              (cellar overlay — native pixels)
 ├─ exec-once: foot -e zellij attach cellar (docked RootCellar session)
 ├─ binds: SUPER+Return terminal · SUPER+B browser · SUPER+D wofi ·
 │         SUPER+Q kill · SUPER+SHIFT+E exit
 └─ apps: firefox, chromium, wofi, foot     (real GUI launching inside WSL)
```

Grounding: Hyprland's `Compositor.cpp` initializes Aquamarine with
`AQ_BACKEND_HEADLESS` as MANDATORY — headless startup is the supported path,
not a hack. wayvnc captures via wlr-screencopy/virtual-pointer, both
implemented by Hyprland. `resize=remote` depends on wlr-output-management;
if Hyprland's support lags, the fallback is a fixed 1920x1080 mode with
client-side scaling (no functional loss, slightly softer pixels).

## Phase 1 (this plan)

1. **modules/webtop.nix**
   - `programs.hyprland.enable = true`
   - packages: foot, wofi, firefox, chromium (XFCE block removed)
   - service `hyprland-headless` replaces labwc-headless + xfce-session:
     `Hyprland -c /etc/cellar/hypr/hyprland.conf`; no WAYLAND_DISPLAY preset
     (the compositor creates its own socket)
   - wayvnc binds `127.0.0.1` (was 0.0.0.0 — LAN exposure under mirrored
     networking); restart-loop tolerance stays for output-creation timing
   - wslg-x11-sockets service stays (XWayland apps still need it)
   - labwc, wlr-randr, XFCE packages removed
2. **deskbottom/hypr/hyprland.conf** (new, deployed via cellarConfigs)
   - exec-once: create headless output; docked foot/zellij terminal
   - monitor rule pinning HEADLESS-1 to 1920x1080
   - keybinds per architecture; animations/blur off (VNC bandwidth)
3. **cellar overlay** (deskbottom/bin/cellar)
   - enumerate Windows monitors via PowerShell interop (absolute path;
     appendWindowsPath=false); PowerShell errors surface, not swallow
   - target: ALL monitors by default — one borderless kiosk per screen,
     mirrored desktop; the largest screen negotiates the framebuffer
     (`resize=remote`), the rest scale the same stream. `cellar overlay
     [n]` targets one monitor alone; `--list` shows the map
   - one `--user-data-dir` per kiosk: a shared dir makes later launches
     join the first window as a tab instead of new fullscreen windows
   - `--force-device-scale-factor=1` (CSS px = physical px on high-DPI)
   - kiosks launch in the background: interop may or may not wait on the
     first process, and every monitor must get its window
   - graceful error when neither browser exists
4. **deploy restarts the user stack** (deskbottom/bin/cellar): a switch
   only *reloads* user units — new units never start, removed units keep
   running (orphaned labwc once held the wayland socket hostage), changed
   units keep stale definitions. Post-switch: daemon-reload, stop known
   retired units, pkill stragglers, try-restart the webtop services.
5. **apps.toml**: `[o]` Desktop overlay entry
6. **docs/THE-DESKBOTTOM.md**: desktop tier rewrite — Hyprland, docked
   session workflow, overlay usage, manual-boot statement, escape hatches,
   ceiling note
7. **Cleanup**: deskbottom/labwc/ removed (autostart concept superseded by
   hyprland.conf exec-once)
8. **Validation**: nix parse + full system eval (deploy-path input rewrite
   into /tmp mirror), bash -n + shellcheck, then live test via cellar update

## Phase 2 (follow-up, not this pass)

True multi-monitor *workspaces*: `hyprctl output create headless` per
external monitor, one wayvnc instance per output (5900, 5901, …), kiosks
joining their own output. Input lands on the focused output; single-user
sequential use is the design target. The mirrored-kiosks overlay in
Phase 1 already covers all screens; this adds independent desktop real
estate per screen.

## Later tiers (recorded, not planned)

- **WSLg tier**: Hyprland nested on WSLg renders directly to native Windows
  windows — no VNC, Direct3D-accelerated, per-window
- **Boot tier**: Windows login task → WezTerm maximized → overlay on all
  screens; Windows becomes the display driver

## Risks

| Risk | Mitigation |
|---|---|
| Hyprland 25.05 headless quirks in no-DRM WSL | Source-verified mandatory headless backend; time-boxed; sway (`WLR_BACKENDS=headless`) is the proven wlroots fallback with identical plumbing |
| resize=remote unsupported by Hyprland's output-management | Fixed 1920x1080 mode + client scaling; Carbonyl/overlay views unaffected |
| XWayland apps | wslg-x11-sockets service already recreates the socket dir writable |
| VNC bandwidth | animations/blur disabled in default config |
