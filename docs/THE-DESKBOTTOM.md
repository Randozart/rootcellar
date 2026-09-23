# The Deskbottom Environment

A desktop environment that lives at the *bottom* of the house. No GUI, no
compositor — yet windows, workspaces, a taskbar, a start menu, files, media
with real sound, and even web pages. All inside one WezTerm window.

## The layers

| Tier | Component | Desktop equivalent |
|------|-----------|--------------------|
| 1 | Zellij (session `cellar`) | Window manager + workspaces |
| 1 | Zellij tab-bar + compact-bar | Taskbar |
| 2 | `cellar app` | Start menu |
| 3 | yazi, btop, lazygit, Neovim, aerc, newsboat, sc-im | The app suite |
| 4 | mpv `--vo=kitty`, chafa, cmus/spotify_player | Media center |
| 5 | WSLg PipeWire audio, labwc desktop (native WSLg window), chafa "wallpaper" | Black magic |
| 6 | TUIOS / tuiui (optional) | A whole second WM, if you want it |

## Booting

An interactive login shell auto-attaches to the Zellij session `cellar` with
the default layout (shell / monitor / files / git tabs). Opt out per session:

```fish
set -gx CELLAR_NO_AUTOSTART 1   # plain shell instead of the deskbottom
```

The session survives: Zellij serializes tabs and pane positions, and reattach
after `wsl --terminate` restores your arrangement.

## The Raddix prompt

The default shell is fish, and the prompt is Raddix — a root veggie with a
little tail. Full spec and color table in `docs/BRANDING.md`; the shape:

```
Success:
  \|╭- <you>@cellar  ~/projects  main
 ⌣⟨'.'⟩⌣≪~ 

Failure:
  ╮|╭- <you>@cellar  ~/projects  main  ✗ 1
_⟨._.⟩_≪~ 
```

The crown `\|` grows out of the neck corner `╭`; the info line branches off
the stem. Below, the head `⟨'.'⟩` hangs between curl-joints, and the tail
`≪~` flicks toward your typing. On failure the neck mirrors (`╮`), the curls
flatten (`_`), the face deflates (`._.`), and the `✗ N` exit code appears —
the tail stops wagging. The face is random from a mood pool on every
successful prompt: `'.'` `' '` `'‿'` `°.°` `•‿•` `˘.˘`.

## The start menu

```bash
cellar            # attach to (or boot) the desktop
cellar app        # fuzzy-pick from apps.toml
cellar app m      # jump straight to Monitor
cellar list       # show apps + which are installed
cellar kill       # tear down the session (asks first)
cellar deploy     # sync repo -> /opt and rebuild (--no-rebuild to skip)
cellar update     # pull from origin, show changes, then deploy
cellar refresh    # clear sessions and boot the desk fresh
cellar ui         # open the desktop (labwc native WSLg window)
```

`cellar deploy` is the whole edit loop for everything in `deskbottom/`,
`modules/`, and `flake.nix`: edit on the Windows side, run one command in
the cellar, done. The sync re-derives the offline flake inputs in `/opt`
after every copy, so the repo keeps real `github:` URLs while the cellar
stays buildable without network.

Register new apps in `desktop/apps.toml` and rebuild. Inside Zellij, apps
open in a new pane; from a bare shell they replace it.

## Keybinds (additions over Zellij defaults)

| Keys | Action |
|------|--------|
| `Alt+h/j/k/l` | Focus pane left/down/up/right |
| `Alt+n` | New pane to the right |
| `Alt+d` | New pane below |
| `Alt+f` | Toggle floating panes |
| `Ctrl+p`, `Ctrl+t` | Zellij pane/tab modes (on-screen hints) |

## Graphics: why WezTerm

Images and video in the terminal ride the **kitty graphics protocol**.
WezTerm (Windows) implements it; Windows Terminal currently does not (sixel
only). `windows/wezterm.lua` is the display driver config:

- yazi file previews and thumbnails render inline
- `chafa picture.png` draws any image in the terminal
- `mpv --vo=kitty video.mkv` plays video in a pane
- `presenterm slides.md` presents slides with images

## Sound

WSLg exposes PipeWire on the Windows side. No configuration needed in the
cellar: `spotify_player`, `mpv`, `cmus` emit real audio. Verify with
`wpctl status` and a sacrificial `speaker-test`.

## Web browsing in the terminal

- **Carbonyl** — Chromium rendering into the terminal, images included.
- **Browsh** — Firefox-driven; text + monochrome images; heavier.

Both are optional installs; `cellar app` will pick them up once registered
in `apps.toml`.

## The Desktop (Tier 5)

A full **labwc** desktop runs as a **native WSLg window** — labwc connects to
WSLg's Weston compositor (`wayland-0`) and the desktop appears on the
Windows desktop like any other app window: real pixels, real input, no
encoding, no browser stream. labwc is the window manager: floating windows,
keybinds, real GUI apps (Firefox, Chromium, GNOME tools), and a docked
RootCellar terminal. What belongs here — and what stays on Windows — is
governed by [docs/PHILOSOPHY.md](PHILOSOPHY.md): the desktop is the escape
hatch for what terminals cannot do, not a clone of the Windows app suite.
Why labwc over the alternatives is recorded in
[docs/DESKTOP-OPTIONS.md](DESKTOP-OPTIONS.md).

Architecture:
```
labwc (nested in WSLg's Weston, WAYLAND_DISPLAY=wayland-0)
  -> native Windows window (WSLg Wayland->DWM bridge)
  -> waybar: start menu, workspaces, taskbar, window controls, hints
```

The compositor starts as a user service (`labwc-headless`) when the
desktop feature is enabled. Two ways in:

- **`cellar ui`** — relaunch the desktop window after a `cellar close`.
- **`cellar overlay` / `cellar maximize`** — toggle the window between
  maximized and windowed; `cellar minimize` hides it to the Windows
  taskbar. The top bar's `─ □ × ⇱` buttons do the same with the mouse.

The old browser-kiosk pipeline (waymote H.264 streaming, noVNC over
websockify, the Carbonyl pane, and the Edge/Chrome kiosk overlay) was
removed — the WSLg-native window superseded it. The `wlroots` axis-source
patch that only existed for waymote's virtual pointer went with it.

Inside the desktop:

- A foot terminal auto-docks to the **same Zellij session** as the
  Windows-side WezTerm (multi-client shared view) — your session is
  already there when the desktop comes up.
- The desk modifier is **Ctrl+Alt**, spelled out in the config. The
  Windows key never reaches the guest (Windows claims it globally), so
  there is no `$mod`/Super indirection. `Ctrl+Alt+Space` start menu ·
  `Ctrl+Alt+T` terminal · `Ctrl+Alt+D` app launcher ·
  `Ctrl+Alt+B` Firefox · `Ctrl+Alt+O` files · `Ctrl+Alt+S` software ·
  `Ctrl+Alt+C` Control Center · `Ctrl+Alt+V` clipboard ·
  `Ctrl+Alt+P` screenshot · `Ctrl+Alt+X` close ·
  `Ctrl+Alt+F` fullscreen · `Ctrl+Alt+W` maximize ·
  `Ctrl+Alt+H`/`L` prev/next window · `Ctrl+Alt+←↓↑→` move ·
  `Ctrl+Alt+Shift+←↓↑→` resize · `Ctrl+Alt+M` send to workspace ·
  `Ctrl+Alt+Q` exit (with confirmation). `Ctrl+Alt+]` / `Ctrl+Alt+[`
  cycle between Windows monitors. The full mouse-first layer is
  docs/CONVENIENT-DESKTOP.md.
- The waybar top panel carries the start menu, workspaces, a clickable
  taskbar, window controls (─ □ ×), help, and the clock.

Getting out: `Alt+F4` on the window closes it; `Ctrl+Alt+Q` exits the
desktop from inside (with confirmation). The cellar never traps you.

The desktop is a native WSLg window (labwc nested in Weston's Wayland→DWM
bridge) — no encoder, no browser, no VNC. `cellar close` shuts it down
fully; `cellar ui` relaunches it from a terminal.

## Tier 6: a whole second window manager

[TUIOS](https://github.com/Gaurav-Gosain/tuios) (BSP tiling, workspaces,
command palette, kitty video playback) and
[tuiui](https://github.com/imthefounder/tuiui) (floating windows, dock,
desktop icons, 600+ TUI app store) are full terminal WMs that coexist with
Zellij — run them as an app inside the cellar when you want the full
desktop-in-a-desktop experience. Not installed by default: Zellij is the
boring, reliable foundation; these are the toy box.
