# PLAN — Keybinds: one prefix, one key

Status: in progress · 2026-09-15
Predecessor: PLAN-VISUAL-PASS.md (catppuccin-mocha visual pass)

## Goal

One modifier, one key, no layers. Every desk action is `Ctrl+Alt+<one key>`.
The same letters mean the same thing in sway and Zellij, so there is one
vocabulary for the whole desktop.

## Why Ctrl+Alt (and why there is no `$mod`)

The modifier is not a preference — it is forced by the environment, and this
section exists so nobody re-litigates it:

- **The Windows key can never reach sway.** WSLg forwards the physical Win key
  to Windows, not to the guest (microsoft/wslg#672, open since 2022). Windows
  also keeps `Win+<arrow>`, `Win+D`, `Win+L` and friends.
- **A sway-side xkb remap cannot manufacture a modifier.** In the nested
  (wayland-backend) case, wlroots forwards key events with
  `.update_state = false` (`backend/wayland/seat.c`), so sway's modifier mask
  comes from **Weston**, not from sway's own keymap. `xkb_options caps:super`
  changes the keysym but never sets the Mod4 bit, so `bindsym Mod4+…` cannot
  fire. The `Win→NumLock, use Mod3` trick fails too: lock bits are excluded
  from `wlr_keyboard_get_modifiers()` (`depressed | latched` only).
- **No evdev keyboard exists in WSLg**, so keyd/kmonad/interception cannot
  help either.

That leaves `Ctrl+Alt`, which Weston forwards reliably. There is no `$mod`
variable: the variable exists only to make the modifier swappable in one place,
and it cannot be swapped. Spelling out `Ctrl+Alt+` makes every bind
self-documenting.

### Why not Ctrl+Shift

`Ctrl+Shift` is forwarded just as reliably and would be easier to reach, but it
shadows far more: foot's `Ctrl+Shift+C/V` (terminal copy/paste), `R` (search),
`N` (new terminal), and ~17 Firefox shortcuts (`T` reopen tab, `W` close
window, `N`, `P`, `R`, `S`, `D`, `B`, `Q`, …). The usual argument for
`Ctrl+Shift` — that `Ctrl+Alt` is AltGr — is **latent here**: wlroots discards
Weston's keymap, so nested sway compiles its own plain-`us` keymap with no
level-3. `Ctrl+Alt` currently collides with nothing.

## The map

sway (`Ctrl+Alt+…`) and Zellij (`Alt+…`) share letters; the prefix picks the
layer.

| Concept | sway | Zellij |
|---|---|---|
| focus | `h j k l` | `h j k l` |
| move | `← ↓ ↑ →` | `← ↓ ↑ →` |
| resize | `r` → arrows | `r` → arrows |
| fullscreen | `f` | `f` |
| float | `w` | `w` |
| close | `x` | `x` |
| new | `t` (terminal) | `n` (pane) |
| workspace / tab | `1…5` | `1…9` |
| move to workspace | `m` (picker) | `m` (pane) |
| menu | `Space` | — |

Full sway bindings live in `deskbottom/sway/config`; the human-readable table is
`deskbottom/bin/cellar-help` (`Ctrl+Alt+F1`).

## The menu: fuzzel, not wofi

wofi 1.4.1 (nixpkgs 25.05) reads its config only from
`$XDG_CONFIG_HOME/wofi/` — it ignores `/etc/xdg/wofi/` (the foot pattern), so a
declarative theme needs a wrapper. fuzzel reads `/etc/xdg/fuzzel/fuzzel.ini`
natively, resolves dmenu icons by **theme name** via the rofi protocol
(`Label\0icon\x1ficon-name`), and themes from a plain INI. It replaces both
`wofi --show drun` (bare `fuzzel`) and `wofi --dmenu`.

Trade-offs: fuzzel is Wayland-only (no X fallback), `--width` is in characters,
there is no `--height` (use `--lines`), and cancel exits 2. wofi stays
installed for one release as a safety net.

## The terminal font

foot used `DejaVu Sans Mono`, which has **no Private Use Area at all**. Zellij's
`tab-bar` and `status-bar` draw exactly one PUA glyph — `U+E0B0`, the Powerline
separator — between tabs and hint groups, so it rendered as tofu. Installing a
Nerd Font does not fix it, because fontconfig's dynamic fallback is
script/language-based and never maps PUA codepoints.

JetBrains Mono carries Powerline (`e0b0-e0b3`) plus all box drawing, rounded
corners and arrows natively, is already in `fonts.packages`, and is the font the
WezTerm config intends. foot renders box/line drawing itself
(`box-drawings-uses-font-glyphs=no`), so only the separator ever needed the
font.

(WezTerm "worked" for a different reason: its configured chain — JetBrains Mono
→ Cascadia Code → Consolas — contains no PUA font at all; it was getting the
glyph from Windows' system fallback, which found the per-user FiraCode Nerd
Font. That config is left alone.)

## Files touched

| File | Change |
|---|---|
| `deskbottom/foot/foot.ini` | `font=JetBrains Mono:size=11` |
| `deskbottom/sway/config` | flat `Ctrl+Alt+…` binds, resize mode, fuzzel |
| `deskbottom/zellij/config.kdl` | the mirror |
| `deskbottom/fuzzel/fuzzel.ini` | new — catppuccin-mocha + Inter |
| `deskbottom/bin/cellar` | wofi→fuzzel, icons in the menu |
| `deskbottom/waybar/config.jsonc`, `config-bottom.jsonc` | fuzzel, flat hint line |
| `deskbottom/bin/cellar-help` | flat table |
| `modules/webtop.nix` | `wofi` → `fuzzel` |
| `modules/deskbottom.nix` | deploy `fuzzel.ini` |
| `docs/CONVENIENT-DESKTOP.md`, `docs/THE-DESKBOTTOM.md` | update |

## Validation

`foot -c … --check-config` · `sway --validate` · Zellij KDL review · JSONC parse
· `bash -n` + `shellcheck` · `nix flake check` + build.
