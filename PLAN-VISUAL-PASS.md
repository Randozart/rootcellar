# PLAN — Visual Pass: Catppuccin Mocha Desktop

Status: in progress · 2026-09-15
Predecessor: PLAN-HYPRDESK.md (architecture pivot to WSLg nesting)

## Problem

The desktop is functional but visually rough:
- DejaVu Sans is utilitarian (not designed for UI at small sizes)
- Waybar colors are ad-hoc hex, not the real catppuccin-mocha palette
- Workspace buttons are invisible (only 1 ever exists, no way to see/create others by mouse)
- The hint bar is a wall of ambiguous text ("H/J/K/L focus" — what does that mean?)
- No mouse-friendly way to move windows between workspaces
- Window borders are thin (2px) with no accent color to show focus

## Goal

A polished catppuccin-mocha desktop that works well with both keyboard AND mouse:
- Inter font everywhere (purpose-built for UI)
- Real catppuccin-mocha palette with `@define-color` variables
- 5 workspace buttons visible, click to switch (persistent)
- Wofi menu for moving windows between workspaces (keyboard + mouse)
- `client.focused` accent borders (mauve), smart_borders (collapse when single window)
- Clear, structured hint bar

## Approach

### Step 1: Typography — Inter + Nerd Fonts
**File: `modules/base.nix`**
- Add `inter` and `nerd-fonts.symbols-only` to `fonts.packages`
- `nerd-fonts.symbols-only` provides icons without patching every font

### Step 2: Sway — accent borders + smart_borders
**File: `deskbottom/sway/config`**
- Add `smart_borders on` (borders collapse to 0 when 1 window)
- Add `client.focused`, `client.focused_inactive`, `client.unfocused`, `client.urgent` with catppuccin-mocha accent colors
- Update `font pango:Inter 10` (was DejaVu Sans)

### Step 3: Top bar — catppuccin palette + persistent workspaces
**Files: `deskbottom/waybar/config.jsonc`, `deskbottom/waybar/style.css`**
- Define catppuccin-mocha colors via `@define-color` at top of style.css
- `sway/workspaces` gets `persistent-workspaces`: {"1":[],"2":[],"3":[],"4":[],"5":[]} — always shows 5 buttons
- CSS: `@mauve` accent on focused workspace, `@surface0` hover, `@subtext0` default
- `wlr/taskbar`: add `icon-size: 16` for app icons
- CSS transitions: `transition: background-color 0.15s ease, color 0.15s ease` on interactive elements
- Window controls stay text glyphs (─ □ × ⇱), styled with `@subtext0`

### Step 4: Bottom hint bar — compact + clear
**Files: `deskbottom/waybar/config-bottom.jsonc`, `deskbottom/waybar/style-bottom.css`**
- Rewrite hint text: group by function, use arrows/symbols instead of letters
- `Focus: ←↓↑→ | Move: ⇧+←↓↑→ | Resize: R | Layout: E | Full: F | Float: ⇧Space | Shot: PrtSc | Help: ⇧?`
- Apply catppuccin palette, Inter font, smaller font-size (11px)

### Step 5: Wofi move-to-workspace
**File: `deskbottom/bin/cellar` — add `cmd_movetoworkspace()`**
- `swaymsg -t get_workspaces | jq -r '.[].name'` → list workspaces
- Pipe into `wofi --dmenu --prompt 'Move to'`
- Selected: `swaymsg "[con_id=$(swaymsg -t get_focused | jq '.id')] move container to workspace $selected"`
- Keybind: `Ctrl+Alt+Shift+m` in sway config

### Step 6: Docs
**File: `docs/CONVENIENT-DESKTOP.md`**
- Update workspace section: 5 persistent buttons, click to switch, move via wofi
- Add `Ctrl+Alt+Shift+m` move-to-workspace keybind
- Update the keybind table

### Validate + commit
- `nix flake check` + `nix build .#nixosConfigurations.rootcellar.config.system.build.toplevel`
- `bash -n` + `shellcheck` on cellar, cellar-help
- `sway --validate -c deskbottom/sway/config`
- Commit + push

## Files touched
| File | Change |
|---|---|
| `modules/base.nix` | Add `inter`, `nerd-fonts.symbols-only` |
| `deskbottom/sway/config` | `smart_borders`, `client.*` colors, Inter font, move-to-workspace bind |
| `deskbottom/waybar/config.jsonc` | persistent workspaces, taskbar icons |
| `deskbottom/waybar/style.css` | Full catppuccin palette, Inter font, transitions |
| `deskbottom/waybar/config-bottom.jsonc` | Rewrite hints |
| `deskbottom/waybar/style-bottom.css` | Catppuccin palette, Inter font |
| `deskbottom/bin/cellar` | `cmd_movetoworkspace()` |
| `docs/CONVENIENT-DESKTOP.md` | Update workspace/move docs |

## What we're NOT doing
- `corner_radius` / `blur` / `shadow` — swayfx-only, scenefx requires DRM FD (verified in source)
- Drag-and-drop between workspace buttons — waybar doesn't support it
- Right-click "move to workspace" on taskbar — wlr/taskbar only supports built-in actions
- nwg-panel replacement — ships no config, custom buttons are icon-only (degrades window controls)
