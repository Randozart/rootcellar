# PLAN-DOCKER-BORE-PLASMA — snappy desktop, working Docker Desktop, conditional BORE scope

Status: approved (user answers locked) · 2026-09-23
Predecessors: PLAN-DOCKER-KERNEL.md (bridge/iptables pins, shipped) ·
PLAN-PLASMA.md (session bring-up, shipped) · PLAN-KEYBINDS.md (Ctrl+Alt, shipped)

Labwc migration is **already committed** (`0ff5e3f` feat · `6660e6b` docs).
This plan is the remaining work: Docker Desktop diagnosis, five Plasma
menu-launch fixes, pinned BORE presets for interactivity, and a
**conditional** BORE scope patch only if the A/B test implicates BORE.

## Non-negotiables (user answers, 2026-09-23)

1. **Symptom**: Docker Desktop stuck on "Starting the Docker Engine…".
2. **Preference**: Windows Docker Desktop (not native-only).
3. **`networkingMode=mirrored` must stay.**
4. **Do the A/B test** (`kernel.sched_bore=0`).
5. **Standing policy**: scope BORE to RootCellar **only if** BORE is the
   problem. Do not ship the scope patch unconditionally.
6. **Snappy interactivity**: pin `kernel.sched_burst_penalty_scale = 2048`.

## Table of contents

1. [Context & evidence](#1-context--evidence)
2. [Phase 0 — Docker Desktop diagnosis (manual, outside git)](#2-phase-0--docker-desktop-diagnosis)
3. [Phase 1 — Plasma menu-launch fixes](#3-phase-1--plasma-menu-launch-fixes)
4. [Phase 2 — Pin BORE interactivity presets](#4-phase-2--pin-bore-interactivity-presets)
5. [Phase 3 — Docs + docker-doctor](#5-phase-3--docs--docker-doctor)
6. [Phase 4 — Conditional BORE scope patch](#6-phase-4--conditional-bore-scope-patch)
7. [Execution order](#7-execution-order)
8. [Validation matrix](#8-validation-matrix)
9. [File change summary](#9-file-change-summary)
10. [Commits](#10-commits)

---

## 1. Context & evidence

### Docker Desktop stuck on engine start

Native `dockerd` in the cellar is **healthy** (bridge/nft/ISO9660 all
`=y`; `cellar docker-doctor` green). Docker Desktop is stuck at
"Starting the Docker Engine…". Last known failure signature (2026-09-18):

```
no route to host 192.168.65.7:2376
daemon did not become ready: context deadline exceeded
```

Upstream links (do not re-diagnose from scratch):

| Issue | Signature |
|---|---|
| microsoft/WSL#40573, docker/for-win#15050, docker/desktop-feedback#397 | 6.18 netlink ABI vs LinuxKit initd compiled for 6.6 → `netlink: 'initd': attribute type 4 has an invalid length` |
| docker/for-win#14691, #14666 | `networkingMode=mirrored` × Docker Desktop networking conflict |

Hypothesis tree (mutually exclusive until A/B decides):

- **H1 — BORE/scheduler**: introduced with the custom kernel era; fixed by
  `sched_bore=0` (or stock kernel) with `networkingMode=mirrored` kept.
- **H2 — 6.18 netlink ABI**: custom-kernel **version** (not BORE) breaks
  LinuxKit initd; fixed only by stock kernel or an upstream Docker fix.
- **H3 — mirrored × Desktop**: already-known upstream conflict; fixed by
  Desktop workarounds that keep mirrored (issue #14691) or upstream patch.
- **H4 — unrelated**: stale Desktop state, port 2376 firewall, etc.

**Mirrored stays in every path.** Stock-kernel control only comments
`kernel=` temporarily; `networkingMode=mirrored` is never removed.

### Plasma menu-launch bugs (still open)

User reports Plasma is snappy after WSL restart, but five launch bugs
remain. Exact sites in `modules/plasma.nix` (untouched by the labwc work
except comments):

| # | Symptom | Site |
|---|---|---|
| 1 | `fuzzel: command not found` / "RootCellar Menu failed"; kate/dolphin also miss PATH | `:205` environment.d has no `PATH` |
| 2 | Taskbar pin never lands | `:450` `apps=` (wrong key for quicklaunch) + marker-gated purge missing after `PANEL_CFG` at `:435` |
| 3 | `plasma-setup` activation exit 127 (`sed` missing) | `:366` first line needs `export PATH=…` |
| 4 | Menu autostart fires too early / wrong Wayland socket | `:273-279` `cellar-menu-autostart` in `ExecStartPost` (inherits `WAYLAND_DISPLAY=wayland-0`=Weston, `Type=simple` races) |
| 5 | kglobalaccel sections clobbered (latent) | `:380-412` `KG_MARKER` + range `/^\[Services\]\[${s}.desktop\]/,/^\[/{d;}` eats the next header |

Commit `b6ce9e2` added feature 4 (open menu on desktop launch); keep the
behavior, change the vehicle (XDG autostart seed, write-once).

### BORE state (research, do not re-do)

- Active: `6.18.40.1-rootcellar-bore+`, `kernel.sched_bore=1`.
- Compiled defaults: offset=24, scale=1536, smoothness=1, inherit=2,
  cache=75000000 (in `bore-18-cachy.patch`).
- Plasma is **already on BORE** (SCHED_OTHER nice 0, fair class, no
  CPUWeight/Nice/AllowedCPUs, no RT tasks box-wide, cpu.weight=100).
- Gap: presets live only as C defaults / docs examples — **not** pinned
  in `modules/sysctl.nix` (today only inotify entries).
- BORE has **no** per-task/cgroup/namespace opt-out. Scoping = custom
  third layered patch (~150–300 lines), opt-in from RootCellar PID 1,
  default-stock elsewhere; never edit `bore-18-cachy.patch`.
- Evidence does **not** yet blame BORE; only ship Phase 4 if Phase 0 says so.

---

## 2. Phase 0 — Docker Desktop diagnosis

**No repo edits in 0a/0b.** User-driven; print instructions, never call
`wsl --shutdown` from a script (AGENTS.md).

### 0a — BORE A/B (fast, no reboot)

```bash
# 1. baseline (expect 1)
sysctl kernel.sched_bore
# 2. flip off (runtime, no reboot)
sudo sysctl -w kernel.sched_bore=0
# 3. stop native docker so Desktop is not fighting it
sudo systemctl stop docker
# 4. start/retry Docker Desktop on Windows; wait for engine
# 5. capture logs if still stuck (Windows side)
#    %LOCALAPPDATA%\Docker\log\host\monitor.log
#    %LOCALAPPDATA%\Docker\log\host\com.docker.backend.exe.log
# 6. WSL-side signature (docker-desktop distro, if present)
wsl -d docker-desktop -u root -- dmesg | grep -iE 'netlink|iso9660|initd'
# 7. restore
sudo sysctl -w kernel.sched_bore=1
```

**Decision after 0a:**

| Result | Meaning | Next |
|---|---|---|
| Desktop starts with `sched_bore=0`, fails with `1` | H1 — BORE is the cause | Phase 4 **on**; pin presets in Phase 2 with `sched_bore=1` still preferred for desktop, but document the regression; **or** keep `sched_bore=0` until Phase 4 lands |
| Still fails with `sched_bore=0` | not BORE | 0b stock-kernel control |

### 0b — Stock-kernel control (manual, disruptive)

User edits `%USERPROFILE%\.wslconfig` (start from
`windows/.wslconfig.example`):

```ini
# TEMPORARILY comment the RootCellar kernel line:
# kernel=C:\\Users\\<you>\\wsl-kernel\\bzImage
# NEVER remove networkingMode=mirrored
```

Then (user runs, not the agent):

```powershell
wsl --shutdown
wsl
```

Retest Docker Desktop. Capture the same logs as 0a.

**Decision after 0b:**

| Result | Meaning | Next |
|---|---|---|
| Desktop starts on **stock** WSL kernel | custom-kernel-related (H1 or H2) | If 0a already cleared BORE → H2 (netlink ABI): document + wait/upstream; Phase 4 only if 0a failed BORE-off. If 0a still failed BORE-off and stock works → **two factors**; prefer H2 + keep BORE for desktop |
| Still fails on **stock** | not the custom kernel (H3 or H4) | Skip Phase 4 entirely; pursue H3 mirrored×Desktop workarounds (docker/for-win#14691) while keeping mirrored |

Always restore `kernel=` and `wsl --shutdown` after 0b. Leave a marker
comment in `.wslconfig` (`# ROOTCELLAR-KERNEL OFF FOR A/B`) so the next
boot is obviously experimental.

### 0c — Log triage (feeds docs, Phase 3)

Patterns to extract for TROUBLESHOOTING.md:

1. `netlink: 'initd': attribute type 4 has an invalid length` → H2.
2. `no route to host 192.168.65.7:2376` / mirrored gateway oddity → H3.
3. `context deadline exceeded` on daemon ready → generic timeout (either).
4. BORE-only strings in `monitor.log` while `sched_bore=0` still fails →
   deprioritize H1.

---

## 3. Phase 1 — Plasma menu-launch fixes

All edits in `modules/plasma.nix`. One commit, five fixes. No
reformatting outside the touched ranges (AGENTS.md small-diff rule).

### 1.1 PATH in environment.d (`:205`)

Today:

```nix
environment.etc."environment.d/10-cellar-xdg-data-dirs.conf".text =
  "XDG_DATA_DIRS=/run/current-system/sw/share\n";
```

Change to a multi-line file:

```nix
environment.etc."environment.d/10-cellar-xdg-data-dirs.conf".text = ''
  XDG_DATA_DIRS=/run/current-system/sw/share
  PATH=/run/current-system/sw/bin''${PATH:+:$PATH}
'';
```

Note: `environment.d` does **not** expand `$PATH` the same as a shell in
all units; the `''${PATH:+…}` nix escape produces `${PATH:+:$PATH}` for
the generator. If user-units still miss PATH after deploy, fall back to
`environment.sessionVariables` + a small `systemd.user.sessionVariables`
block — verify live, do not guess twice.

### 1.2 Taskbar pin key + purge (`:435`, `:450`)

1. Inside the existing `PANEL_CFG` write (after `:435`), **before** the
   marker check, unconditionally purge a stale `apps=` key on the
   quicklaunch General section if present (old wrong key from
   `b29fe04`):

   ```bash
   # leave this comment explaining why: older seeds wrote apps=,
   # Plasma 6 quicklaunch reads launcherUrls=
   sed -i '/^\[Containments\]\[20\]\[Applets\]\[[0-9]*\]\[Configuration\]\[General\]$/,/^\[/{/^\(apps=\|launcherUrls=\).*cellar-menu\.desktop/d;}' "$PANEL_CFG" 2>/dev/null || true
   ```

   Prefer a narrow range; if the sed range is too fragile, grep+delete
   only lines containing `apps=file:///run/current-system/sw/...cellar-menu`
   (document the choice in a comment).

2. Change the written line `:450`:

   ```
   launcherUrls=file:///run/current-system/sw/share/applications/cellar-menu.desktop
   ```

3. Keep `PIN_MARKER` so we never stack multiple quicklaunch applets;
   the purge runs even when the marker exists (heals existing installs).

### 1.3 Activation PATH (`:366`)

First line of `system.userActivationScripts.plasma-setup`:

```bash
export PATH="/run/current-system/sw/bin:$PATH"
```

Activation scripts run with a minimal PATH (`sed`/`grep` may be absent).

### 1.4 Menu autostart vehicle (`:273-279`)

- **Remove** the `cellar-menu-autostart` entry from `ExecStartPost`
  (keep `cellar-kwin-poststart`).
- **Add** a write-once XDG autostart entry in the same activation script
  (new section, after the desktop icon seed is fine):

  ```
  mkdir -p "$HOME/.config/autostart"
  if [ ! -f "$HOME/.config/autostart/cellar-menu.desktop" ]; then
    cat > "$HOME/.config/autostart/cellar-menu.desktop" <<'MEOF'
  [Desktop Entry]
  Type=Application
  Name=RootCellar Menu
  Exec=/run/current-system/sw/bin/cellar menu
  X-GNOME-Autostart-enabled=true
  MEOF
  fi
  ```

  Rationale (comment in nix): plasmashell reads autostart after the
  session exists — correct Wayland socket and shell-ready timing —
  without Type=simple ExecStartPost racing.

- If a previous deploy already spawned the broken autostart, no cleanup
  needed (it was unit-local, not user-disk).

### 1.5 kglobalaccel seed rewrite (`:380-412`)

- Drop `KG_MARKER`.
- Every activation run: delete the four `[Services][*.desktop]` sections
  with a **correct** range, then append the absolute-path entries.

  Correct delete for `foo.desktop` (keeps the following header):

  ```bash
  sed -i "s/^\[Services\]\[${s}\.desktop\]/__DEL_START__/; :a; n; /^\[Services\]\[/!{ /^$/!d; b a; }; s/^__DEL_START__.*$//;" "$KGSRC"
  ```

  If that is too clever for AGENTS.md "boring", use the portable form:

  ```bash
  # awk one-pass: drop exact section [Services][${s}.desktop] through
  # the line before the next [ header, but keep that header.
  ```

  Prefer awk with an explicit comment — the existing range delete is the
  latent bug and must not ship again. Verify with a fixture file in the
  PR description (before/after dump).

- Always append the four sections (menu, extend-next, extend-prev,
  control-center) after the delete pass; idempotent because delete
  precedes append.

### 1.6 Live verification (post-deploy, `cellar.toml` stays plasma=true)

```bash
cellar deploy          # first deploy after plasma.nix code changes
# PATH
systemctl --user show-environment | grep '^PATH='   # or: machinectl user
command -v fuzzel; command -v kate; command -v dolphin
# activation
echo $?  # from a fresh deploy — plasma-setup must be 0
# pin
grep -n launcherUrls ~/.config/plasma-org.kde.plasma.desktop-appletsrc
# kglobals
grep -c '^\[Services\]\[' ~/.config/kglobalshortcutsrc   # ≥4 cellar sections
# autostart
ls ~/.config/autostart/cellar-menu.desktop
# menu paths
# kickoff RootCellar Menu, taskbar pin, desktop icon, Ctrl+Alt+Space, Ctrl+Alt+E
```

Restart plasmashell once (`systemctl --user restart plasma-plasmashell`)
to re-read seeds without a full `wsl --shutdown`.

---

## 4. Phase 2 — Pin BORE interactivity presets

File: `modules/sysctl.nix` (additive; keep existing inotify keys first).

```nix
boot.kernel.sysctl = {
  # existing inotify keys … 

  # BORE: pin max-interactivity desktop presets (docs/BORE-SCHEDULER.md).
  # Compiled defaults are 1536; the cellar prefers snappy interactive
  # response over build throughput (user choice 2026-09-23).
  "kernel.sched_bore" = 1;
  "kernel.sched_burst_penalty_scale" = 2048;
  # offset/smoothness/inherit/cache stay at CachyOS defaults — pin only
  # what we intentionally change, so a future patch default bump shows up
  # as a deliberate diff.
};
```

**Interaction with Phase 0:** if 0a proves BORE breaks Docker Desktop,
set `"kernel.sched_bore" = 0` here until Phase 4 ships, and document the
hold in BORE-SCHEDULER.md (one paragraph, link to this plan). Do not
silently ship `sched_bore=1` while Desktop is broken.

Per-process verification recipe to append to
`docs/BORE-SCHEDULER.md` (§ Tunables or a new "Is BORE applying?"):

```bash
sysctl kernel.sched_bore kernel.sched_burst_penalty_scale
# per-task (needs debug or sched show on this kernel):
cat /proc/$(pgrep -n plasmashell)/sched | head -20
# heavier load while watching: scores / wait times should move vs sched_bore=0
```

No kernel rebuild for Phase 2 — pure sysctl.

---

## 5. Phase 3 — Docs + docker-doctor

### 5.1 `docs/TROUBLESHOOTING.md` — new subsection under Kernel & or a Docker section

**`docker-desktop` stuck on "Starting the Docker Engine…"`**

- Check order:
  1. `sysctl kernel.sched_bore` and retest after `=0` (Phase 0a).
  2. `zgrep CONFIG_ISO9660_FS /proc/config.gz` (already documented).
  3. Native engine conflict: `sudo systemctl stop docker` while testing
     Desktop (WSL2 Integration / competing listeners on the docker
     socket).
  4. Logs: `%LOCALAPPDATA%\Docker\log\host\monitor.log`,
     `com.docker.backend.exe.log`; `wsl -d docker-desktop -u root --
     dmesg | grep -iE 'netlink|iso9660|initd'`.
  5. Decision table mirroring Phase 0 (stock vs custom, BORE on/off).
- Link upstream issues (WSL#40573, for-win#15050, #14691) — do not
  paste long threads.
- Explicitly: `networkingMode=mirrored` stays; stock-kernel A/B only
  comments `kernel=`.

### 5.2 `docs/BORE-SCHEDULER.md`

- Split the Docker Desktop section: keep ISO9660/bridge contract; add
  "A/B for engine-start stalls" pointing at this plan.
- Document pinned presets (Phase 2) under Workload presets: the cellar
  now ships scale=2048 (was example-only).
- If Phase 4 runs: add a **compatibility bullet** — custom scope patch
  is the third layered patch; default is stock EEVDF for non-RootCellar
  processes/distros.

### 5.3 `deskbottom/bin/cellar` → `cmd_docker_doctor` (`:745`)

Add checks (keep existing ISO9660/bridge/nft_compat output):

1. **Docker Desktop process**: `tasklist.exe` / path probe for
   `com.docker.backend.exe` (interop; degrade to "unknown if interop down").
2. **Desktop distro state**: `wsl -l -q` contains `docker-desktop`;
   if present, `wsl -d docker-desktop -u root -- true` probe →
   running / stopped / broken.
3. **`networkingMode=`** from `%USERPROFILE%\.wslconfig` (already
   partially in `cmd_netcheck`; call out mirrored explicitly with the
   "stuck engine + mirrored known issue" hint).
4. **Windows docker CLI context**: `docker context ls` (or
   `docker context show`) → flag `desktop-linux` as a red herring when
   native daemon is the one running (context points at Desktop).
5. **Native engine**: keep; add "stop before A/B-testing Desktop" hint
   when both could run.

Shellcheck-zero; no secrets; no `wsl --shutdown` from the script — print
the instruction.

### 5.4 `docs/PERFORMANCE-TUNING.md` §4

One-line update: cellar pins `sched_burst_penalty_scale=2048` via
`modules/sysctl.nix` (link BORE-SCHEDULER).

---

## 6. Phase 4 — Conditional BORE scope patch

**Gate: only if Phase 0 decision table selects H1 (or dual-factor with
BORE implicated).** If H2/H3/H4, stop after Phase 3 docs.

### Design constraints

- **Do not edit** `kernel/patches/bore-18-cachy.patch` (patch-watch
  CI owns it; `PATCH_VERSION` sha is the contract).
- New file: `kernel/patches/rootcellar-bore-scope.patch`.
- Apply **after** BORE + msft fixups in `kernel/build-kernel.sh` with an
  idempotent marker (same pattern as existing patches: skip if already
  applied, fail loudly if fuzz > 0).
- Update `kernel/PATCH_VERSION` in the **same commit** (AGENTS.md):
  new `scope_patch=` + sha256 + date fields (extend the key format
  carefully — readers are `check-upstream.sh` and humans).

### Behavior (minimal viable scope)

Opt-in **stock EEVDF** for everything that is not RootCellar:

1. Boot default: BORE **on** (existing) **or** BORE **off** then enable
   only for RootCellar — pick **default-off + opt-in from PID 1** so
   Docker Desktop / other distros match stock Microsoft behavior with
   zero knowledge of us.
2. Mechanism sketch (must be re-verified against `bore-18-cachy.patch`
   before coding — do not guess scheduler hooks):
   - New sysctl `kernel.sched_bore_scope` (0=all, 1=opt-in, 2=all-except-opt-out).
   - Opt-in via cgroup/`prctl` or by detecting `/etc/cellar/scope`
       present + PID 1 chain — **choose the smallest surface that
       survives `unshare`/containerd** (Desktop's initd must see stock).
   - Default: tasks not opted in run pure EEVDF.
3. ~150–300 lines expected; if the fair.c touch points make this larger
   or racy, **abort Phase 4** and document "BORE cannot be scoped;
   Desktop needs H2/H3 fix or `sched_bore=0` globally".

### Explicit non-goals

- Two kernels / per-distro `.wslconfig` (impossible; `kernel=` is
  global to the utility VM).
- BPF/LSM gating (overkill, fragile on WSL).
- Editing CachyOS upstream patch contents.

### Validation (Phase 4 only)

- `bash -n` + `shellcheck` on `build-kernel.sh`.
- Apply-patch idempotency: run apply twice, second run skips.
- After user rebuild + `wsl --shutdown`:
  - `uname -r` still `*-rootcellar-bore`.
  - Docker Desktop A/B retest (Desktop must start without `sched_bore=0`).
  - RootCellar interactive still feels snappy under `stress-ng`.
  - `PATCH_VERSION` sha matches new files.

---

## 7. Execution order

Recommended (agent can parallelize docs while user runs Phase 0):

| Step | Owner | Blocking? |
|---|---|---|
| A. Phase 0a (BORE A/B + log capture) | user | gates Phase 4 + Phase 2 `sched_bore` value |
| B. Phase 1 (plasma.nix five fixes) | agent | no |
| C. Phase 2 (sysctl pin; `sched_bore` 0 vs 1 per 0a) | agent | soft-block on 0a result |
| D. Phase 3 (TROUBLESHOOTING, BORE-SCHEDULER, docker-doctor, PERFORMANCE-TUNING) | agent | can draft with placeholders, finalize after 0a/0b |
| E. Single `cellar deploy` for B+C+D | user | after B+C+D commits |
| F. Phase 0b stock-kernel control | user | only if 0a fails; disruptive |
| G. Phase 4 scope patch | agent | only if 0a/0b select H1 |
| H. Kernel rebuild + final Desktop verify | user | only if G |

Do **not** start G without a written decision line in this plan's status
(or a follow-up commit updating the status header).

---

## 8. Validation matrix

| Change | Must run |
|---|---|
| `modules/plasma.nix` | `nix-instantiate --parse modules/plasma.nix` (or `nix flake check` if available) |
| `modules/sysctl.nix` | same |
| `deskbottom/bin/cellar` | `bash -n` + `shellcheck deskbottom/bin/cellar` (zero new warnings) |
| `docs/*` | re-read for drift vs code; issue links factual |
| `kernel/build-kernel.sh` / `kernel/patches/rootcellar-bore-scope.patch` | `bash -n` + shellcheck; `PATCH_VERSION` updated same commit; double-apply idempotency |
| After deploy | Plasma live checklist in §1.6; `sysctl -a` shows pins; `cellar docker-doctor` output reviewed |

If a validator is unavailable, say so in the summary (AGENTS.md).

---

## 9. File change summary

| File | Phase | Change |
|---|---|---|
| `modules/plasma.nix` | 1 | PATH env.d; launcherUrls + purge; activation PATH; drop ExecStartPost menu, XDG autostart seed; kglobals always rewrite |
| `modules/sysctl.nix` | 2 | pin `sched_bore` (0 or 1 per A/B) + `sched_burst_penalty_scale=2048` |
| `docs/TROUBLESHOOTING.md` | 3 | "Docker Desktop stuck engine starting" decision tree |
| `docs/BORE-SCHEDULER.md` | 3 | A/B recipe, pinned presets, optional Phase 4 compat bullet |
| `docs/PERFORMANCE-TUNING.md` | 3 | §4 one-liner for pinned scale |
| `deskbottom/bin/cellar` | 3 | `cmd_docker_doctor` Desktop/distro/context/mirrored checks |
| `kernel/patches/rootcellar-bore-scope.patch` | 4* | new (gated) |
| `kernel/build-kernel.sh` | 4* | third apply + idempotency (gated) |
| `kernel/PATCH_VERSION` | 4* | scope sha + date same commit (gated) |
| `cellar.toml` | — | **never staged** (session toggle; currently plasma=true) |

\* Phase 4 files only if the gate opens.

---

## 10. Commits

Conventional Commits, one logical change each (AGENTS.md):

1. `fix(plasma): menu launch bugs (PATH, pin key, activation, autostart, seeding)`
2. `feat(sched): pin BORE max-interactivity presets for the desktop`
3. `fix(docker): diagnose Desktop engine-start failures; extend docker-doctor`
4. *(gated)* `kernel(bore): scope scheduler to RootCellar only` +
   `PATCH_VERSION` in the same commit (or amend into 4 if still one
   logical change)

Already shipped (not part of this plan's remaining work):

- `0ff5e3f` `feat(desktop): migrate webtop compositor from sway to labwc`
- `6660e6b` `docs(desk): document labwc desktop and retire sway prose`

## Status log

- 2026-09-23: plan written; user answers locked; labwc commits landed.
- Pending: Phase 0a user run → then B/C/D as gated above.
