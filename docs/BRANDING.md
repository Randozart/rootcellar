# RootCellar Branding — The Raddix Standard

Everything visual in RootCellar derives from one creature: **Raddix the
radish** — *radish* + *radix* (Latin: root), patron saint of the room
without Windows. This document is the single source of truth for the
identity. If code and this document disagree, one of them is a bug.

## Identity

| Context | Name |
|---------|------|
| Repo | `rootcellar` |
| Project | RootCellar |
| Formal (releases, badges) | RootCellar OS |
| WSL distro (registration) | `RootCellar` |
| Hostname | `cellar` |
| Kernel release | `6.18.x-rootcellar-bore` |
| Shell prompt | `randy@cellar` |
| Mascot | **Raddix** (`⟨'.'⟩`) |

## Palette

| Role | Hex | Used for |
|------|-----|----------|
| Root white | `#F5F3F1` | foreground, face, body |
| Turnip purple | `#B07DE8` | accents, `⟨ ⟩` body, `❯`/`≪~`, active tab |
| Nix dark blue | `#5277C3` | frame/neck `╭-`, root strokes, selection |
| Nix light blue | `#7EBAE5` | paths, leaves, `⌣` curls, `\|` stem |
| Cellar bg | `#191622` | terminal backdrop |
| Dim | `#6F6785` | failure state, secondary text |
| Functional red* | `#D0879A` | ANSI red only (muted rose, in-family) |
| Functional green* | `#6FBFAD` | ANSI green only (muted sea-glass) |
| Functional cyan* | `#5EBFAD` | ANSI cyan only (muted teal, distinct from blue) |

*The UI chrome uses only white/purple/Nix blues. The ANSI 16-color slots
keep muted functional hues so tools (git diff, ls) stay legible; they are
desaturated to sit inside the family. `LS_COLORS` is set explicitly
(modules/deskbottom.nix): foreground-only, no background colors — solid
dir backgrounds (coreutils' green-bg world-writable default) are banned
because they swallow filenames.*

## The Raddix Prompt

The default (and only) shell is **fish**. `fish_prompt.fish` draws:

```
Success:
  ────────────────────────────────────────────
   \|╭- randy@cellar  ~/projects  main
 ⌣⟨'.'⟩⌣≪~ 

Failure (exit 1):
  ────────────────────────────────────────────
   ╮|╭- randy@cellar  ~/projects  main  ✗ 1
 _⟨._.⟩_≪~ 
```

In failure, the branches (`_`) keep their blue color; only the turnip
brackets and tail dim to grey. The whole creature stays recognizably
RootCellar — just wilted.

### Anatomy

- `────` — the soil line: full-width rule (dark blue) above the crown,
  marking the ground between commands. Box-drawing, never underscores —
  a straight line without gaps.
- `\|` — the crown: shadow leaf (dark blue) + stem (light blue)
- `╭-` — the neck: frame corner as stem; the info line branches off it
  like a tag tied to the veggie
- `⟨'.'⟩` — the head: brackets are the body silhouette, the face lives
  inside
- `⌣ ... ⌣` — curl-joints holding the head
- `≪~` — the tail: flick + wiggle, fading into the soil where your
  command grows

### Faces

A face is three characters between the brackets. Random face per prompt
on success; the veggie moods through your day.

| Face | Mood |
|------|------|
| `'.'` | alert (the classic) |
| `' '` | sleepy content |
| `'‿'` | quietly delighted |
| `°.°` | startled |
| `•‿•` | smug |
| `˘.˘` | drowsy |

### The wilt (failure state)

One-character changes, structural sadness:

- neck mirrors: `╭` → `╮` (the stem snaps the wrong way)
- curls flatten: `⌣` → `_` (the bounce dies)
- face deflates: `'.'` → `._.` (fixed until the next success)
- turnip brackets and tail dim one step; branches stay blue
- `✗ N` shows the exit code inline

No red. Even failure stays in the palette — just sad.

## Glyph language

The identity speaks in one glyph family; reuse it everywhere:

| Glyph | Meaning |
|-------|---------|
| `─` | soil line (full-width rule above the prompt) |
| `⌒` | leaflet (alive) |
| `⌢` | drooped leaflet (wilted) |
| `⋎` | sprouting stem (crown center) |
| `⌣` | curl-joint / little tail |
| `◠ ◡` | round body silhouette |
| `⟨ ⟩` | body brackets |
| `≪ ~` | tail flick + wiggle (cursor marker) |

Safe set for alignment-sensitive contexts: `⌒ ⌢ ⌣ ◠ ◡ ╲ ╱ ∿ ‿ ⟨ ⟩ ≪`.
Exotic diagonals (`⟍⟋ ⧸⧹`) are banned from prompts — fallback-font width
drift breaks alignment.

## Raddix portrait (fastfetch / MOTD)

```
    ⌒ ⋎ ⌒
  ⌒ ⌒   ⌒ ⌒
   .──────.
  (  '.'  )
   '──────'
     ╲╱
     ⌣
```

ANSI-colored: leaves light blue, crown purple, body white, frame dark
blue. Caption: `Raddix · RootCellar OS`. WezTerm tab sigil uses the
compact form: `⟨◠( '' )◡⟩`.

## Modifying Raddix

Everything the veggie is made of is plain text in this repo. Edit on the
Windows side, deploy from the cellar, commit when happy.

| You want to touch… | Edit… | Deployed to… | Applies… |
|---|---|---|---|
| The prompt creature (crown, neck, face pool, curls, wilt) | `deskbottom/shell/fish_prompt.fish` | `/etc/cellar/fish_prompt.fish` | new shell/pane |
| The portrait (login + fastfetch art) | `deskbottom/fastfetch/raddix.ans` | `/etc/motd`, fastfetch | next login |
| The Root/Cellar wordmark | `assets/rootcellar-ascii.ans` | `/etc/motd` | next login |
| WezTerm tab sigil | `windows/wezterm.lua` (`format-tab-title`) | `%USERPROFILE%\.wezterm.lua` | WezTerm reloads instantly |
| Ribbon / mode pill (zjstatus format) | `deskbottom/zellij/layouts/*.kdl` | `/etc/cellar/zellij/layouts/` | fresh zellij session |
| MOTD assembly (order, wording) | `modules/deskbottom.nix` (`cellarConfigs`) | `/etc/motd` | next login |

Deploy loop, from the cellar (config-only changes rebuild in ~30s):

```bash
sudo cp /mnt/c/Users/randy/Documents/Projects/rootcellar/deskbottom/shell/fish_prompt.fish \
        /opt/rootcellar/deskbottom/shell/fish_prompt.fish
sudo nixos-rebuild switch --flake /opt/rootcellar#rootcellar
```

Live-iterate the prompt without rebuilding (the deployed file is a
read-only store symlink, but fish sources anything):

```fish
cp /etc/cellar/fish_prompt.fish /tmp/raddix-test.fish
$EDITOR /tmp/raddix-test.fish
source /tmp/raddix-test.fish   # your very next prompt is the prototype
```

Notes:

- The `.ans` art files contain raw ESC bytes (`^[` in nvim). Tweak glyph
  rows freely; recolor deliberately — every color code should already be
  in the palette.
- Zellij layouts are snapshotted at session start. After a layout change,
  `zellij delete-all-sessions --yes` or you will meet the old world again
  (session resurrection replays the serialized tabs).
- Fold live-tested edits back into the repo copy before rebuilding, so
  the repo stays the source of truth.

## Rules

1. No emoji anywhere in the terminal identity. The veggie is drawn, not
   pasted.
2. New UI surfaces inherit the palette — never introduce new hues.
3. The face pool may grow, but every face is exactly three characters of
   ASCII/Unicode punctuation. No letters, no words.
4. Raddix does not speak. The veggie's mood is conveyed by face and tail
   alone.
