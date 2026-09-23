# Desktop options for the cellar (latency-first survey)

This is the write-up of every desktop route considered when Plasma's
latency became the deciding factor, plus the reasoning that landed on
**labwc**. Revisit this before ever re-litigating the desktop choice.

## The problem

Plasma (KWin 6 + plasmashell) works but feels slow. The latency is
**structural, not a config bug**: every frame from a Plasma app travels
app → KWin scene-graph → QPainter raster → Weston → RDP → Windows, all
software-rendered (this box has no GPU — llvmpipe/QPainter only). You can
shave KWin's animations/effects, but Plasma *requires* KWin and KWin *is*
the cost. Plasma-via-X11 is a confirmed dead end in WSLg
(microsoft/wslg#1286), so there is no lighter-Plasma route.

## WSLg constraints (apply to every option)

- WSLg exposes **Weston** at `wayland-0` and **Xwayland** at `:0`. The
  `:0` WM slot is taken by Weston's own XWM — no X11 window manager can
  claim it ("Another Window Manager is already running").
- A desktop under WSLg is always **one native Windows window**, in both
  protocols: the desktop's WM must run *inside* a single Weston client
  (a nested Wayland compositor, or a nested Xwayland `:1`) to exist at
  all. "Each app its own Windows window" is only possible by dropping
  the desktop concept and living on `:0` with Weston's minimal XWM.
- All rendering is software. The discriminator is **pixman/XRender-safe
  (fine) vs GL-only (blocked or slow)** — no `/dev/dri`, so any GL-only
  compositor dies (that wall killed Hyprland and swayfx).

## The verified menu

| Stack | Renderer | Weight | Panel/DE | NixOS (25.05) | Verdict |
|---|---|---|---|---|---|
| sway (had) | wlroots **pixman** | fastest | waybar + nwg-drawer + cellar | custom service | proven, tiling |
| **labwc** | wlroots pixman | fastest | reuse waybar/nwg-drawer/cellar | `programs.labwc.enable` | **chosen** — floating, same speed |
| river | wlroots pixman | fastest | waybar `river/tags` | `programs.river.enable` | tiling, different config style |
| LXQt 2.2 | X11, **zero compositor** | fast | full panel/runner/settings | `services.xserver.desktopManager.lxqt.enable` | "a lighter Plasma" (Qt) |
| Xfce 4.20 | XRender | light-medium | full DE | `services.xserver.desktopManager.xfce.enable` | classic, proven |
| MATE | XRender | light-medium | full DE | `services.xserver.desktopManager.mate.enable` | GTK, heavier than LXQt |
| GNOME 48 | GL-over-llvmpipe | heavy | full shell | `services.xserver.desktopManager.gnome.enable` | viable only via `--nested` hack |
| Wayfire / Hyprland | **GL-only** | — | — | `programs.wayfire.enable` | **blocked** (no `/dev/dri`) |

Verified against the repo's pin (nixos-25.05, rev ac62194c). All three
wlroots compositors run pixman (no GL). The X11 DEs run against a nested
Xwayland `:1` with `services.xserver.enable = false` (modules act as
package installers; no display manager fires — keep it that way).

## Why labwc

1. **Same speed tier as the already-proven sway** — wlroots + pixman,
   nested in Weston identically (`WLR_BACKENDS=wayland wayland-0`). No
   GL, no new renderer.
2. **Floating-window desktop feel** instead of sway's tiling — closer to
   the "a desktop" mental model, without KWin's weight.
3. **Reuses the entire convenience layer** — waybar, nwg-drawer, fuzzel,
   cellar menu, swww, mako all work on labwc (wlr-layer-shell +
   foreign-toplevel). Smallest migration surface of any DE option.
4. `programs.labwc.enable` is a clean NixOS module; no display manager
   required (we start it from a `systemd.user` service exactly like the
   old `sway-headless`).

### Known labwc trade-offs (accepted)

- **No IPC.** The WSLg close-recovery becomes "detect missing `WL-*`
  output via `wlr-randr`, restart `labwc-headless`" — a visible blip on
  RDP wake instead of sway's silent `swaymsg create_output`.
- **No gaps, no modes, no tiling.** `layout toggle`, `floating toggle`,
  `smart_borders`, the 8px gaps and the resize mode do not translate;
  resize becomes direct `ResizeRelative` binds.
- **Modifier-release quirk.** labwc 0.8.3+ forwards modifier release to
  apps, so `Ctrl+Alt` keybinds can pop Firefox's menu bar. Accepted —
  Super is unusable on WSLg (wslg#672).
- **No "urgent" window state** (sway's `client.urgent` has no mapping).
- The WSLg window is titled `labwc - WL-1`; windowctl's title match list
  grew a `labwc` entry.

## Revisiting the menu later

- **LXQt** is the closest thing to "Plasma, minus the weight": Qt6, the
  same visual language, openbox as WM (no compositor = zero compositing
  cost). If a fuller DE is ever wanted, this is the first stop — but it
  means a nested-Xwayland build and its X11 quirks (alt-tab input
  stickiness, unreliable fullscreen inside nested Xwayland, weaker
  decorations).
- **Plasma** remains available via `cellar session plasma` for the
  heavy-polish desktop; its menu-launch bugs are queued for a follow-up
  fix pass (see PLAN-DOCKER-BORE-PLASMA.md).
- **GNOME** is viable only through the `gnome-shell --nested` X11-window
  hack with unit overrides + daemon masking; it auto-disables animations
  under llvmpipe, but it is the heaviest viable option — not a latency
  play.
- **Wayfire/Hyprland/swayfx stay blocked** until a render node exists.

## Decision record

- 2026-09-22: chose **labwc** over sway (floating feel), LXQt/Xfce (DE
  builds + X11 quirks), GNOME (heavy + hacky), Plasma (structural
  latency). Commits: docs record + `desk: migrate webtop compositor to
  labwc`.