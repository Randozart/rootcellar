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
| Start menu | `cellar menu` — a fuzzel menu with Papirus icons, branching into Applications, Terminal, Files, Software, Settings, System | waybar `≡` button, `Ctrl+Alt+Space` |
| Full start menu | `nwg-menu` — categorized apps, search, power menu | waybar `⊞` button |
| App grid | `nwg-drawer` — icons, search, categories, power bar | menu → Applications |
| App launcher | `fuzzel` over XDG `.desktop` entries | `Ctrl+Alt+D` |
| Hotkey hints | thin bottom bar: the direct `Ctrl+Alt` binds + a live mode tag | bottom edge |
| Taskbar | waybar `wlr/taskbar` — every running window | waybar centre |
| Workspaces | waybar `sway/workspaces` — buttons 1–5 always visible; click to switch (sway creates a workspace on demand) | top bar left |
| Software center | `cellar store` — search nixpkgs, click a result, install declaratively | menu → Software, `Ctrl+Alt+S` |
| Move to monitor | `cellar extend [n]` — fill another monitor; `cellar shrink` un-maximizes | waybar `⇱`, `cellar extend` |
| Notifications | mako | `exec mako` |
| Clipboard history | cliphist + wl-clipboard | `Ctrl+Alt+V` |
| Screenshot | grim + slurp → clipboard | `Ctrl+Alt+P` |
| Auto-tiling | `autotiling` — splits along the longer edge | `exec autotiling` |
| Theme | catppuccin GTK, papirus icons, Bibata cursors | sway env + gtk settings |

## Why not swayfx

swayfx (sway with blur/rounded corners/shadows) was evaluated and rejected:
its GLES2 `fx_renderer` requires a DRM FD, and this WSL2 environment has no
GPU and renders software-only. It cannot start here. The compositor stays
stock sway; the polish comes from the shell, the theme, and the binds.

## The wheel

This is deliberately **not** a from-scratch desktop. The established pieces
are used where they exist: `nwg-drawer` from the nwg-shell project,
`autotiling` for sane splits, and the catppuccin/papirus/Bibata theme trio.
We hand-roll only the parts that are specific to the cellar (`cellar`
commands, the declarative software center, the WSLg window controls).

## The package manager stays declarative

`cellar store` never installs imperatively. It runs `nix search`, shows the
results in fuzzel, and on click calls `cellar add` — which appends to
`modules/user-packages.list`, commits, and offers to deploy. The GUI is a
front end for the same declarative flow the CLI (`cellar pkgs`) uses.
Nothing lands in a `nix profile`; everything is in git.

## Moving the window

The sway window has no title bar (WSLg RAIL windows get no Windows caption,
and sway draws no client decorations) and is usually maximized, so it cannot
be dragged. `cellar extend [n]` moves it onto a chosen monitor and fills it
(`n` skips the picker); `cellar shrink` un-maximizes it. The waybar `⇱`
button opens the picker. `Win+Shift+Left/Right` also moves it between
monitors, Windows-native.

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
