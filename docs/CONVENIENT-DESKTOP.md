# The Convenient Desktop

The deskbottom is keyboard-first: Zellij, fish, nvim, `cellar`. This layer
adds a **mouse-first path on top** — a start menu, an app grid, a dock, a
graphical software center, and the small services that make GTK apps feel
native — without taking the keyboard away.

**Design rule:** every mouse action has a keybind equivalent. The mouse is a
shortcut, never the only way in.

## The pieces

| Piece | What it is | How to reach it |
|---|---|---|
| Start menu | `cellar menu` — a fuzzel menu with Papirus icons; rows are probed live and session-native (sway: Applications/Terminal/Files/…; both: a Screen section with fullscreen, resize and monitor moves) | waybar `≡` button, `Ctrl+Alt+Space`, kickoff "RootCellar Menu" in the Plasma session |
| App grid | `nwg-drawer` — icons, search, categories, power bar | menu → Applications |
| App launcher | `fuzzel` over XDG `.desktop` entries | `Ctrl+Alt+D` |
| Hotkey hints | thin bottom bar: the direct `Ctrl+Alt` binds + a live mode tag | bottom edge |
| Taskbar | waybar `wlr/taskbar` — every running window | waybar centre |
| Workspaces | waybar `sway/workspaces` — buttons 1–5 always visible; click to switch (sway creates a workspace on demand) | top bar left |
| Software center | `cellar store` — search nixpkgs, click a result, install declaratively | menu → Software, `Ctrl+Alt+S` |
| Control center | Qt6/QML GUI — packages, flake viewer, rebuild with progress, settings | `Ctrl+Alt+C`, menu → Software (Plasma) |
| Move to monitor | `cellar extend [n]` — fill another monitor; `cellar shrink` un-maximizes | waybar `⇱`, `cellar extend` |
| Notifications | mako | `exec mako` |
| Clipboard history | cliphist + wl-clipboard | `Ctrl+Alt+V` |
| Screenshot | grim + slurp → clipboard | `Ctrl+Alt+P` |
| Auto-tiling | `autotiling` — splits along the longer edge | `exec autotiling` |
| Theme | catppuccin + cellar palette (translucent, matched to the terminal), papirus icons, Bibata cursors | sway env, gtk settings, `cellar-gtk-css` |

## Why not swayfx

swayfx (sway with blur/rounded corners/shadows) was evaluated and rejected:
its GLES2 `fx_renderer` requires a DRM FD, and this WSL2 environment has no
GPU and renders software-only. It cannot start here. The compositor stays
stock sway; the polish comes from the shell, the theme, and the binds.

## The Plasma session

`cellar session plasma && cellar deploy` swaps the whole desktop for KDE
Plasma 6 (`cellar session sway` switches back) — see PLAN-PLASMA.md for
the full design. What to expect:

- Same nesting model: `startplasma-wayland` runs as a Wayland client of
  WSLg's Weston, so Plasma appears as a native Windows window —
  auto-maximized at launch through the same windowctl path the sway
  window uses. `cellar maximize` is idempotent (always maximizes);
  `cellar overlay` is the toggle. Closing the session stops plasmashell
  cleanly with it — no crash dialogs afterwards.
- **The RootCellar rice**: an `org.rootcellar.desktop` look-and-feel
  applies the cellar palette (`#191622` family, Raddix purple accent)
  as a RootCellar color scheme, with Bibata cursors and Papirus icons,
  and the cellar's default wallpaper. Applied once on first boot
  (marker-guarded); after that System Settings is yours.
- **Software rendering, deliberately**: the service sets
  `KWIN_COMPOSE=Q` (QPainter) — there is no GPU here, and GL-over-llvmpipe
  is the slow path. Expect less animation polish than sway.
- `plasma-powerdevil`, `plasma-polkit-agent` and `plasma-baloorunner` are
  masked: power management has nothing to manage in a VM, the polkit GUI
  agent crash-loops, and indexing the store is CPU waste.
- PipeWire's socket is pulled in at user-manager start (plasmashell's
  media monitor otherwise spams connection errors), and
  `PULSE_SERVER` points libpulse clients at WSLg's RDP audio server —
  playback lands on the Windows side.
- `cellar overlay` / `maximize` / `minimize` / `extend` / `resize` work
  through windowctl, which matches both the sway ("wlroots") and KWin
  ("kwin") window titles.
- **Mouse-first, three keys only**: Plasma gets no replica of the sway
  keyboard workflow — the desktop is reachable by mouse. The cellar
  menu lives in kickoff as **RootCellar Menu** (pin it to the taskbar)
  and carries a Screen section: fullscreen, resize presets and monitor
  moves. Seeded shortcuts cover the rest: `Ctrl+Alt+Space` (menu),
  `Ctrl+Alt+E` / `Ctrl+Alt+Shift+E` (next/previous monitor). Everything
  else is KDE's own shortcuts — Meta-based ones never fire (WSLg sends
  the Windows key to Windows), and KRunner (`Alt+Space`) is the native
  launcher.
- **Session-native app sets**: `apps.toml` entries carry a `plasma`
  command (dolphin, kate, kcalc, gwenview, ark, systemsettings,
  plasma-systemmonitor); entries without one are sway-only and never
  offered in a Plasma session. `cellar app` / `cellar list` resolve by
  the live session, and the menu probes tools before rendering rows.

## The wheel

This is deliberately **not** a from-scratch desktop. The established pieces
are used where they exist: `nwg-drawer` from the nwg-shell project,
`autotiling` for sane splits, and the catppuccin/papirus/Bibata theme trio.
We hand-roll only the parts that are specific to the cellar (`cellar`
commands, the declarative software center, the WSLg window controls).

## Packages: local or frozen (the software center)

There are **three states**, and the software center (`Ctrl+Alt+S`, `cellar
center`) moves packages between them with buttons — no config editing:

| State | Where | Rebuild? | In git? | Verbs |
|---|---|---|---|---|
| **System** | the flake's own package set | (already in) | yes | — (edit modules to change) |
| **Local** | this user's `nix profile` | no | no | `cellar use` / `cellar unuse` |
| **Frozen** | `modules/user-packages.list` | yes | yes | `cellar freeze` / `cellar unfreeze` |

The intended flow: search → **Install** (try it now, no rebuild) → happy?
→ **Freeze in** (write it into the declarative list, git commit) →
**Deploy** (rebuild with one sudo password). Packages that ship with the
base (the static tool chest, devtools, webtop) badge as **system** — the
center hides Freeze in for them, since they are already declared in the
flake. The **System** view lists the entire closure — every package the
current OS ships, with descriptions, straight from a manifest generated
at build time. Running an install, freeze or unfreeze shows a modal
spinner until the cellar verb returns. The Deploy dialog asks only for
the sudo password and runs `cellar deploy-root`, then `cellar
deploy-user` as the user.

`cellar store` (the fuzzel quick picker) still appends declaratively via
`cellar add`; `cellar profile --json` / `cellar frozen --json` /
`/etc/xdg/cellar/system-packages` expose the three states for the GUI.
Local packages are the fast lane for iterating; frozen packages are what a
fresh deploy reproduces.

## Moving the window

The compositor window has no title bar (WSLg RAIL windows get no Windows
caption, and sway draws no client decorations) and is usually maximized,
so it cannot be dragged. `cellar extend next` / `cellar extend prev` hop
between monitors cyclically (sway keybinds `Ctrl+Alt+]` / `Ctrl+Alt+[`;
plasma keybinds `Ctrl+Alt+E` / `Ctrl+Alt+Shift+E`). Bare `cellar extend`,
the waybar `⇱` button or the menu's Monitor picker opens a fuzzel picker.
`Win+Shift+Left/Right` also moves it between monitors, Windows-native.

Sizing is the same story: `cellar resize [WxH]` sets an explicit size
(bare: fuzzel preset picker), `cellar maximize` fills the screen and
`cellar shrink` restores the window. In the Plasma session the menu's
Screen section drives all of them by mouse.

## Zellij: the desktop gets its own session

Zellij sizes a shared session to the **smallest** attached client (a shared
grid cannot show two sizes). The Windows-side WezTerm and the in-desktop
foot were fighting over one session, so the smaller clamped the larger.

The desktop's foot now runs its **own** session (`cellar-desk`), separate
from the terminal deskbottom's `cellar`. Each renders at its own size. The
trade-off is deliberate: panes are no longer shared between the two, because
a shared session cannot have two sizes. (Zellij 0.45+ softens this with
per-tab sizing, but nixpkgs pins 0.43.)

## Window management

Sway tiles by default: a new window splits the focused one, containers nest,
nothing overlaps. Every desk action is exactly `Ctrl+Alt+<one key>` — one
prefix, no layers (see PLAN-KEYBINDS.md for why it cannot be Super).

| Keys | Action |
|---|---|
| `Ctrl+Alt+H/J/K/L` | focus left/down/up/right |
| `Ctrl+Alt+←↓↑→` | move the window |
| `Ctrl+Alt+R` | resize mode (arrows, then Esc) |
| `Ctrl+Alt+W` | toggle floating |
| `Ctrl+Alt+E` | layout: split / tabbed / stacking |
| `Ctrl+Alt+F` | fullscreen |
| `Ctrl+Alt+X` | close window |
| `Ctrl+Alt+1…5` | workspaces (buttons always visible in the top bar — click to switch) |
| `Ctrl+Alt+M` | move window to a picked workspace (type a new number to create it) |
| `Ctrl+Alt+Q` | exit sway (confirms) |
| `Ctrl+Alt+]` | next monitor |
| `Ctrl+Alt+[` | previous monitor |

Mouse (tiling kept — the mouse just makes it easier):

| Gesture | Action |
|---|---|
| `Ctrl+Alt`+left-drag | move a window (it floats and follows the cursor) |
| `Ctrl+Alt`+right-drag | resize a window |
| drag a window's border | resize |
| click a taskbar entry | focus; middle-click closes |
| click a workspace button | switch to that workspace |
| `Ctrl+Alt+M` | move the focused window to another workspace |

## Launching

| Keys | Action |
|---|---|
| `Ctrl+Alt+Space` | Start menu |
| `Ctrl+Alt+T` | Terminal |
| `Ctrl+Alt+D` | Apps (fuzzel) |
| `Ctrl+Alt+B` | Firefox |
| `Ctrl+Alt+O` | Files |
| `Ctrl+Alt+S` | Software center |
| `Ctrl+Alt+C` | Settings |
| `Ctrl+Alt+V` | Clipboard history |
| `Ctrl+Alt+P` | Region screenshot to clipboard |
| `Ctrl+Alt+F1` | This help |

## Keybinds are the contract

Every entry in the start menu also has a binding, and every binding appears
in `cellar-help` (`Ctrl+Alt+F1`). Adding a menu entry means adding a
bind, and vice versa — see AGENTS.md, "docs live with behaviour".
