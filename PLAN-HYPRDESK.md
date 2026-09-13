# PLAN — HyprDesk: The cellar's desktop environment

Status: in progress · 2026-09-12
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

## Outcome 2026-09-11: Hyprland failed, sway fallback invoked

Hyprland 0.49 aborts at startup in this environment:
`CBackend::create() failed!` — aquamarine's headless backend starts, but
the allocator stage requires a DRM node (GBM) and the cellar has none:
no `/dev/dri`, no WSLg compositor mounted, no dxg/virtio-gpu in the bore
kernel. The Wayland fallback backend found only a stale socket and died
on missing protocols. This is structural: Hyprland cannot run here
without a GPU node or a nesting compositor.

Per the risk table below, the fallback was invoked: **sway** (wlroots +
pixman software rendering), the same family as the proven labwc stack.
Same plumbing: sway-headless service, `deskbottom/sway/config` with the
same keybinds and docked-session autostart, wayvnc/websockify unchanged.
Revisit Hyprland only if the cellar gains a DRM node (GPU-enabled kernel
config or a WSLg nesting compositor).

## Phase 2 (follow-up, not this pass)

True multi-monitor *workspaces*: `hyprctl output create headless` per
external monitor, one wayvnc instance per output (5900, 5901, …), kiosks
joining their own output. Input lands on the focused output; single-user
sequential use is the design target. The mirrored-kiosks overlay in
Phase 1 already covers all screens; this adds independent desktop real
estate per screen.

## Phase 3: Full desktop — waybar, gaps, wofi, wallpaper visible

The overlay streamed a single fullscreen terminal. No panel, no launcher,
no visible desktop. Phase 3 rewrites the sway config for a desktop-first
layout: waybar panel, app launcher, tiling gaps, wallpaper visible on
empty workspaces.

### Problem

The sway config was 61 lines: one `exec foot`, one `for_window fullscreen
enable`, wallpaper, keybindings. The entire "desktop experience" was a
single foot terminal with zellij, fullscreened. The overlay delivered an
RDP-to-terminal, not a desktop.

### Solution

1. **modules/webtop.nix** — add `waybar` and `wl-clipboard` to packages
2. **deskbottom/sway/config** — rewrite for desktop-first layout:
   - `exec waybar` (top panel: workspaces, clock, window title)
   - `gaps inner 8` (visible gaps → wallpaper shows between windows)
   - `default_border pixel 2` (thin border, not 0)
   - `exec swaybg` stays (wallpaper renderer)
   - `SUPER+Return` opens a local foot (independent terminal)
   - `SUPER+Shift+Return` opens cellar-dock (shared zellij session)
   - No forced fullscreen on cellar-dock (tiles normally)
3. **deskbottom/waybar/config.jsonc** — waybar config (new file):
   - Top bar, 28px, rootcellar plum palette
   - Left: workspaces 1-5
   - Center: window title
   - Right: clock
4. **deskbottom/waybar/style.css** — waybar styling (new file):
   - RootCellar theme colors (#191622 bg, #F5F3F1 fg)
   - Clean, minimal
5. **deskbottom/bin/cellar** — overlay URL fix:
   - Remove resize_url / scale_url distinction (framebuffer fixed at
     1536x960 by the headless backend; renegotiation just causes
     multi-client size fights)
   - All kiosks use a single URL:
     `?autoconnect=1&reconnect=1&resize=scale&qualityLevel=9&compressionLevel=1`
     — `resize=scale` is noVNC's native client-side scaling: the canvas
     fills whatever window/monitor the kiosk occupies, framebuffer
     unchanged
   - foot.ini deploys to /etc/xdg/foot/foot.ini (foot's actual search
     path — /etc/foot is never read; verified via foot --check-config)

### What the user sees

- Browser kiosk opens: waybar panel across the top (workspaces, clock)
- Wallpaper visible on empty workspaces and behind tiled windows
- `SUPER+Return` → new foot terminal (local, not shared with WezTerm)
- `SUPER+D` → wofi launcher (drun mode)
- `SUPER+Q` → kills focused window
- `SUPER+F` → toggles fullscreen
- `SUPER+1-5` → switch workspaces
- Windows tile with 8px gaps — wallpaper visible between them
- cellar-dock shared session: available via `SUPER+Shift+Return`

### What this does NOT change

- The cellar-dock shared session: still works, just not forced fullscreen
- wayvnc / websockify / noVNC pipeline: untouched
- The webtop.nix service definitions: untouched
- Deploy/restart flow: unchanged

### Validation

- `bash -n` + `shellcheck` on cellar
- `nix-instantiate --parse` on webtop.nix
- waybar config valid JSONC
- Live test: `cellar update && cellar overlay`

### Commit

`feat(desktop): full sway desktop — waybar, gaps, wofi, wallpaper visible`

## Later tiers (recorded, not planned)

### Tier R: RemoteApp over RDP loopback — Windows apps tiled in the desktop

The real answer to "window-in Windows apps through interop" (see
docs/PHILOSOPHY.md, the guest ladder). Windows 11 Business hosts RDP;
freerdp (Wayland client, in nixpkgs) runs inside sway and connects to
`localhost:3389`; published RemoteApps (Teams, Outlook) appear as
ordinary tiled windows in the desktop, streamed through the overlay with
everything else.

- Apps run in a real Windows session: genuine mic, camera, GPU
- Session audio plays on the host speakers (RDP remote-audio mode) —
  sound never touches the cellar's missing audio stack
- Loopback RDP is the same pipe WSLg uses; latency is near zero

Sketch: enable RDP host + firewall rule for 3389 (mirrored mode + Hyper-V
firewall may need an explicit allow); publish RemoteApps; package
freerdp2/3 + a `cellar remote` command that starts the freerdp Wayland
client with `/app:` program lists.

Caveats: RDP-ing into the own user session takes it over from the
console (mostly moot under a fullscreen overlay); GPO-managed machines
may fight publishing or the firewall; freerdp RemoteApp quirks are
app-specific.

### Tier W: WSLg-native windows

Hyprland/sway nested on WSLg renders directly to native Windows windows —
no VNC, Direct3D-accelerated, per-window. Requires the WSLg compositor
to be mounted (absent in this setup today) and a GPU-capable kernel.

### Tier B: boot tier

Windows login task → WezTerm maximized → overlay on all screens; Windows
becomes the display driver. Manual boot remains the default per user
requirements; this tier is opt-in at most.

## Risks

| Risk | Mitigation |
|---|---|
| Hyprland 25.05 headless quirks in no-DRM WSL | Source-verified mandatory headless backend; time-boxed; sway (`WLR_BACKENDS=headless`) is the proven wlroots fallback with identical plumbing |
| resize=remote unsupported by Hyprland's output-management | Fixed 1920x1080 mode + client scaling; Carbonyl/overlay views unaffected |
| XWayland apps | wslg-x11-sockets service already recreates the socket dir writable |
| VNC bandwidth | animations/blur disabled in default config |
