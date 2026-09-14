# The Convenient Desktop

The deskbottom is keyboard-first: Zellij, fish, nvim, `cellar`. This layer
adds a **mouse-first path on top** — a start menu, an app launcher, a
taskbar, a graphical software center, and the small services that make GTK
apps feel native — without taking the keyboard away.

**Design rule:** every mouse action has a keybind equivalent. The mouse is a
shortcut, never the only way in.

## Pieces

| Piece | What it is | How to reach it |
|---|---|---|
| Start menu | `cellar menu` — a wofi menu branching into Applications, Terminal, Files, Software, Settings, System | waybar `≡` button, `Ctrl+Alt+Space` |
| App launcher | `wofi --show drun` over XDG `.desktop` entries | `Ctrl+Alt+D`, menu → Applications |
| Taskbar | waybar `wlr/taskbar` — every running window, click to focus | waybar centre |
| Software center | `cellar store` — search nixpkgs, click a result, install declaratively | menu → Software, `Ctrl+Alt+Shift+D` |
| Notifications | mako | `exec mako` |
| Clipboard history | cliphist + wl-clipboard | `Ctrl+Alt+Shift+V` |
| Screenshot | grim + slurp → clipboard | `Print` |
| GUI apps | nautilus, gnome-text-editor, gnome-calculator, gnome-system-monitor, loupe, file-roller | apps.toml, menu |
| Portals | xdg-desktop-portal (+ gtk) — file dialogs, screenshots for GTK apps | service |
| Theme | papirus icons + a cursor theme | sway env |

## The package manager stays declarative

`cellar store` never installs imperatively. It runs `nix search`, shows the
results in wofi, and on click calls `cellar add` — which appends to
`modules/user-packages.list`, commits, and offers to deploy. The GUI is a
front end for the same declarative flow the CLI (`cellar pkgs`) uses.

Nothing lands in a `nix profile`. Everything is in git. This is why the
software center is a wofi front end and not `nix-software-center`:
the latter installs imperatively (or edits a traditional
`/etc/nixos/configuration.nix` that this flake-based system does not have).

## Why wofi

wofi is already the launcher (`Ctrl+Alt+D`). It renders XDG `.desktop` entries
with icons, is fully clickable, and speaks dmenu — so the same binary is the
app launcher, the start menu, the keybinding sheet, and the software center.
One dependency, four jobs. A richer launcher (anyrun, walker) is a possible
upgrade, not a need.

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
in `cellar-help` (`$mod+Shift+?`). Adding a menu entry means adding a bind,
and vice versa — see AGENTS.md, "docs live with behaviour".
