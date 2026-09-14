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
| Start menu | `cellar menu` — a wofi menu branching into Applications, Terminal, Files, Software, Settings, System | waybar `≡` button, `Ctrl+Alt+Space` |
| App grid | `nwg-drawer` — icons, search, categories, power bar | menu → Applications |
| App launcher | `wofi --show drun` over XDG `.desktop` entries | `Ctrl+Alt+D` |
| Dock | `nwg-dock` — pinned apps + tasks, auto-hide | bottom edge |
| Taskbar | waybar `wlr/taskbar` — every running window | waybar centre |
| Software center | `cellar store` — search nixpkgs, click a result, install declaratively | menu → Software, `Ctrl+Alt+Shift+D` |
| Notifications | mako | `exec mako` |
| Clipboard history | cliphist + wl-clipboard | `Ctrl+Alt+Shift+V` |
| Screenshot | grim + slurp → clipboard | `Print` |
| Auto-tiling | `autotiling` — splits along the longer edge | `exec autotiling` |
| Theme | catppuccin GTK, papirus icons, Bibata cursors | sway env + gtk settings |

## Why not swayfx

swayfx (sway with blur/rounded corners/shadows) was evaluated and rejected:
its GLES2 `fx_renderer` requires a DRM FD, and this WSL2 environment has no
GPU and renders software-only. It cannot start here. The compositor stays
stock sway; the polish comes from the shell, the theme, and the binds.

## The wheel

This is deliberately **not** a from-scratch desktop. The established pieces
are used where they exist: `nwg-drawer`/`nwg-dock` from the nwg-shell
project, `autotiling` for sane splits, and the catppuccin/papirus/Bibata
theme trio. We hand-roll only the parts that are specific to the cellar
(`cellar` commands, the declarative software center, the WSLg window
controls).

## The package manager stays declarative

`cellar store` never installs imperatively. It runs `nix search`, shows the
results in wofi, and on click calls `cellar add` — which appends to
`modules/user-packages.list`, commits, and offers to deploy. The GUI is a
front end for the same declarative flow the CLI (`cellar pkgs`) uses.
Nothing lands in a `nix profile`; everything is in git.

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
nothing overlaps. The desk binds cover the whole model:

| Keys | Action |
|---|---|
| `Ctrl+Alt+H/J/K/L` | focus left/down/up/right |
| `Ctrl+Alt+Shift+H/J/K/L` | move the window |
| `Ctrl+Alt+R` | resize mode (arrows, then Esc) |
| `Ctrl+Alt+Shift+Space` | toggle floating |
| `Ctrl+Alt+E` | layout: split / tabbed / stacking |
| `Ctrl+Alt+F` | fullscreen |
| `Ctrl+Alt+1…5` | workspaces |
| `Ctrl+Alt+Shift+1…5` | move window to workspace |

## Keybinds added

| Keys | Action |
|---|---|
| `Ctrl+Alt+Space` | Start menu |
| `Ctrl+Alt+D` | App launcher (unchanged) |
| `Ctrl+Alt+Shift+D` | Software center |
| `Ctrl+Alt+Shift+V` | Clipboard history |
| `Print` | Region screenshot to clipboard |

## Keybinds are the contract

Every entry in the start menu also has a binding, and every binding appears
in `cellar-help` (`Ctrl+Alt+Shift+?`). Adding a menu entry means adding a
bind, and vice versa — see AGENTS.md, "docs live with behaviour".
