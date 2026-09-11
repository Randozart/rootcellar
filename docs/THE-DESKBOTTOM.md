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
| 5 | WSLg PipeWire audio, Carbonyl + noVNC desktop, chafa "wallpaper" | Black magic |
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
cellar webtop     # open the XFCE desktop in a Carbonyl pane
cellar refresh    # clear sessions and boot the desk fresh
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

A full **Hyprland** desktop runs headlessly inside the cellar and streams
to any browser via noVNC. Hyprland is the window manager: tiled windows,
keybinds, real GUI apps (Firefox, Chromium), and a docked RootCellar
terminal.

Architecture:
```
Hyprland (headless Wayland) -> wayvnc -> websockify -> noVNC
                                               |- Carbonyl pane (in-terminal)
                                               `- Edge/Chrome kiosk (native)
```

The compositor boots headless with the distro (invisible, harmless) —
nothing interrupts your terminal until *you* open a viewer. There are
two ways in:

- **`cellar webtop`** (`cellar app b`) — the desktop in a Carbonyl pane.
  The stream is pixel-perfect (`resize=remote`: the framebuffer matches
  the pane viewport), but a terminal pane quantizes pixels into cells —
  fine for a glance, not for working.
- **`cellar overlay [n]`** (`cellar app o`) — the fullscreen tier. Spawns
  a borderless Edge/Chrome kiosk on Windows monitor `n` (first
  non-primary by default; `cellar overlay --list` shows the map). Native
  pixels, native input — Hyprland keybinds pass straight through.

Inside the desktop:

- A foot terminal auto-docks to the **same Zellij session** as the
  Windows-side WezTerm (multi-client shared view) — your session is
  already there when the desktop comes up.
- `SUPER+Return` terminal · `SUPER+B` Firefox · `SUPER+D` wofi launcher ·
  `SUPER+Q` close window · `SUPER+SHIFT+E` exit the compositor.

Getting out: `Alt+F4` on the kiosk (or `SUPER+SHIFT+E` inside) returns to
the terminal. The cellar never traps you.

The headless output's ceiling is 1920x1080
(`monitor=` line in `deskbottom/hypr/hyprland.conf`) — raise it to your
display's native resolution for the overlay tier. Multiple simultaneous
viewers: only one client should use `resize=remote` (they negotiate the
framebuffer size); plain `vnc.html` viewers just scale.

## Tier 6: a whole second window manager

[TUIOS](https://github.com/Gaurav-Gosain/tuios) (BSP tiling, workspaces,
command palette, kitty video playback) and
[tuiui](https://github.com/imthefounder/tuiui) (floating windows, dock,
desktop icons, 600+ TUI app store) are full terminal WMs that coexist with
Zellij — run them as an app inside the cellar when you want the full
desktop-in-a-desktop experience. Not installed by default: Zellij is the
boring, reliable foundation; these are the toy box.
