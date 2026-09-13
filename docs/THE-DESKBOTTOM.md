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

A full **sway** desktop runs headlessly inside the cellar and streams
to any browser via noVNC. sway is the window manager: tiled windows,
keybinds, real GUI apps (Firefox, Chromium), and a docked RootCellar
terminal. What belongs here — and what stays on Windows — is governed
by [docs/PHILOSOPHY.md](PHILOSOPHY.md): the desktop is the escape hatch
for what terminals cannot do, not a clone of the Windows app suite.

Architecture:
```
sway (headless Wayland) -> wayvnc -> websockify -> noVNC
|                                              |- Carbonyl pane (in-terminal)
|                                              `- Edge/Chrome kiosk (--vnc)
`-> waymote (H.264/WebCodecs) -> Edge/Chrome kiosk (default overlay)
```

The compositor boots headless with the distro (invisible, harmless) —
nothing interrupts your terminal until *you* open a viewer. There are
two ways in:

- **`cellar webtop`** (`cellar app b`) — the desktop in a Carbonyl pane.
  The stream is pixel-perfect (`resize=remote`: the framebuffer matches
  the pane viewport), but a terminal pane quantizes pixels into cells —
  fine for a glance, not for working.
- **`cellar overlay [n]`** (`cellar app o`) — the fullscreen tier. Spawns
  a borderless Edge/Chrome kiosk on **every** Windows monitor (primary
  included), each showing the same mirrored desktop; `cellar overlay n`
  targets monitor `n` alone and `cellar overlay --list` shows the map.
  Native pixels, native input — sway keybinds pass straight through.

The default overlay stream is [waymote](https://github.com/rockorager/waymote):
the gateway (`127.0.0.1:8090`) captures the headless output through
waymote-streamd, encodes H.264 with libx264, and the kiosk decodes it
via WebCodecs. The output is pinned to the panel's **physical**
1920x1200 at 1.25 scale (`deskbottom/sway/config`): UI proportions
match the Windows side's logical 1536x960 while the stream carries
native pixels — crisp at 125% Windows scaling, smooth in motion.
`cellar overlay --vnc` falls back to the noVNC stack (`resize=remote`)
for debugging or if waymote (a young v0.1.x project) misbehaves.

Inside the desktop:

- A foot terminal auto-docks to the **same Zellij session** as the
  Windows-side WezTerm (multi-client shared view) — your session is
  already there when the desktop comes up. `cellar overlay` closes the
  Windows-side WezTerm while the kiosk is up, so the shared session's
  grid is the kiosk's alone (Zellij renders at the smallest attached
  client); WezTerm reattaches on next launch.
- Keybinds use **Ctrl+Alt as `$mod`** — Windows claims the Windows key,
  so the cellar stopped fighting it. `$mod+Return` terminal ·
  `$mod+B` Firefox · `$mod+D` wofi launcher · `$mod+Q` close window ·
  `$mod+T` toggle split · `$mod+SHIFT+K` exit kiosk ·
  `$mod+SHIFT+E` exit the compositor (with confirmation).
- The kiosk client carries a small toolbar (bottom-center): menu, new
  pane, exit kiosk — each dispatches the matching keybind through the
  stream, so they work identically to the keyboard.

Getting out: `Alt+F4` on the kiosk (or `SUPER+SHIFT+E` inside) returns to
the terminal. The cellar never traps you.

The headless output's size follows whoever manages it: waymote pins it
to 1920x1200 for the overlay, while `resize=remote` VNC clients
(webtop, `--vnc` kiosk) negotiate it to their viewport. Running both at
once makes them fight over the size — use one tier at a time.

## Tier 6: a whole second window manager

[TUIOS](https://github.com/Gaurav-Gosain/tuios) (BSP tiling, workspaces,
command palette, kitty video playback) and
[tuiui](https://github.com/imthefounder/tuiui) (floating windows, dock,
desktop icons, 600+ TUI app store) are full terminal WMs that coexist with
Zellij — run them as an app inside the cellar when you want the full
desktop-in-a-desktop experience. Not installed by default: Zellij is the
boring, reliable foundation; these are the toy box.
