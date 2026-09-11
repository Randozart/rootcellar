# The RootCellar Doctrine

How to decide what belongs in the cellar. This document is the tie-breaker
for every "should this run in WSL or on Windows" question — when code,
config, or ambition disagrees with it, one of them is a bug.

## Statement of primacy

RootCellar is the primary environment. Windows is demoted to what it is
genuinely needed for: the display driver, the GPU, the microphone, the
camera, and corporate-managed applications. Prefer the CLI; prefer the
cellar. Windows apps are guests — summoned from within, tiled where
possible, Alt+Tab where the hardware boundary demands it.

The cellar never pretends to be Windows, and Windows never gets to hang
a compilation again.

## Why this is not maximalism

Every GUI app installed in WSL is a worse version of one Windows already
runs: software-rendered, streamed, starved of audio and input devices.
Installing the WSL twin of a native Windows app does not gain
sovereignty — it loses quality while doubling maintenance. Sovereignty
means the cellar never *needs* Windows, not that it clones it badly.

## The placement test

An app belongs in the cellar when any of these hold:

- Its context is the terminal (dev servers, TUI tools, compilers)
- It is Linux-native and exists nowhere better (foot, wofi, wayvnc)
- It is *about* the cellar's own content — a real browser for reading
  docs and web apps tied to dev work

An app stays on Windows when any of these hold:

- It needs microphone, camera, or GPU (the WSL device boundary is
  hardware, not configuration — see the limitations table below)
- It is corporate-managed and the license or GPO says Windows
- Windows runs it strictly better and nothing in the workflow cares

Concrete examples: Firefox/Chromium — cellar (real browsing is the
point of the desktop tier). Teams calls, Zoom, Discord voice — Windows,
via interop launchers, full stop. Teams chat and Outlook mail — either;
desktop residents are fine for reading and composing, calls are not.

## The hardware boundary (honest table)

| Resource | Cellar status | Why |
|----------|---------------|-----|
| Compile speed | **Best here** | Linux fs, BORE kernel, dedicated RAM — the cellar is the fast machine |
| Keyboard/mouse | Works | Streamed through noVNC / overlay kiosk |
| Display pixels | Works | wlroots headless + wayvnc; see PLAN-HYPRDESK.md |
| Audio out | Missing | No sound server; /mnt/wslg/pulseaudio absent in this setup |
| Microphone | Unavailable | WSL device model; no reliable capture path |
| Camera | Unavailable | No /dev/video; usbipd + UVC kernel module is a project, not a toggle |
| GPU | Unavailable | No DRM node in the bore kernel; software rendering only |

The guest-ladder below exists precisely to route around this table:
apps that need the right-hand column run in Windows sessions, reached
from inside the cellar.

## The guest ladder (Windows apps, best first)

1. **RemoteApp over RDP loopback** (the goal): Windows hosts RemoteApps;
   freerdp inside the desktop connects to `localhost:3389`; each app
   appears as an ordinary tiled window in the sway desktop. Apps run in
   a real Windows session with genuine mic/camera; session audio stays
   on the host speakers. Status: designed, not yet built
   (PLAN-HYPRDESK.md).
2. **Interop launchers** (built): `cellar app` opens the native Windows
   binary (msedge.exe, OUTLOOK.EXE, ms-teams). The window appears on the
   Windows desktop.
3. **Alt+Tab** (always available): Windows windows stack above the
   overlay kiosk; the honest zero-setup fallback.

## The pragmatic clause

This is still a Windows machine, and the host is family (as
`.wslconfig` already says). Sovereignty is measured by what the cellar
can do alone — not by pretending the host's hardware does not exist.
When a task genuinely belongs to the host, delegate it cleanly and stay
in the custom space for everything else.
