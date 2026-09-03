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
| Turnip purple | `#A06BE0` | accents, `⟨ ⟩` body, `❯`/`≪~`, active tab |
| Nix dark blue | `#5277C3` | frame/neck `╭-`, root strokes, selection |
| Nix light blue | `#7EBAE5` | paths, leaves, `⌣` curls, `\|` stem |
| Cellar bg | `#191622` | terminal backdrop |
| Dim | `#6F6785` | failure state, secondary text |
| Functional red* | `#D0879A` | ANSI red only (muted rose, in-family) |
| Functional green* | `#6FBFAD` | ANSI green only (muted sea-glass) |

*The UI chrome uses only white/purple/Nix blues. The ANSI 16-color slots
keep muted functional hues so tools (git diff, ls) stay legible; they are
desaturated to sit inside the family.

## The Raddix Prompt

The default (and only) shell is **fish**. `fish_prompt.fish` draws:

```
Success:
  \|╭- randy@cellar  ~/projects  main
 ⌣⟨'.'⟩⌣≪~ 

Failure (exit 1):
  ╮|╭- randy@cellar  ~/projects  main  ✗ 1
_⟨._.⟩_≪~ 
```

### Anatomy

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
- everything dims one step; `✗ N` shows the exit code inline

No red. Even failure stays in the palette — just sad.

## Glyph language

The identity speaks in one glyph family; reuse it everywhere:

| Glyph | Meaning |
|-------|---------|
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

## Rules

1. No emoji anywhere in the terminal identity. The veggie is drawn, not
   pasted.
2. New UI surfaces inherit the palette — never introduce new hues.
3. The face pool may grow, but every face is exactly three characters of
   ASCII/Unicode punctuation. No letters, no words.
4. Raddix does not speak. The veggie's mood is conveyed by face and tail
   alone.
