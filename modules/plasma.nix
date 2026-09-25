# KDE Plasma 6 desktop, nested inside WSLg's Weston compositor.
# Mutually exclusive with the webtop labwc desktop (webtop.nix): enabling plasma
# disables webtop so only one compositor runs at a time.
#
# KWin becomes a Wayland client of WSLg's Weston on wayland-0 — the same
# model labwc uses.  SDDM is forcibly disabled: WSLg owns the display
# lifecycle, so no display manager is needed.
#
# The Ctrl+Alt modifier constraint applies here too (WSLg sends Win to
# Windows, not the guest — see PLAN-KEYBINDS.md).  Super-based KDE
# shortcuts simply never fire; window management runs through the cellar
# verbs (`cellar overlay`, `cellar extend`) until a proper kwinrc
# remapping exists.  First-boot theming is seeded declaratively — see
# PLAN-PLASMA.md for the crash-loop diagnosis (powerdevil, polkit-agent)
# and the masking rationale.
{ config, lib, pkgs, ... }:

let
  cfg = config.cellar;

  # The RootCellar Plasma rice: a RootCellar color scheme (cellar palette
  # on the BreezeDark structure — schema-correct by construction) and the
  # org.rootcellar.desktop look-and-feel package that cascades it with
  # Bibata cursors and Papirus icons. The plasma6 module links /share
  # into the system profile, so KPackage finds both.
  cellar-plasma-theme = pkgs.stdenvNoCC.mkDerivation {
    pname = "cellar-plasma-theme";
    version = "1.0.0";
    src = ../deskbottom/plasma;
    dontBuild = true;
    installPhase = ''
      mkdir -p $out/share/color-schemes $out/share/plasma/look-and-feel
      cp RootCellar.colors $out/share/color-schemes/
      cp -r look-and-feel/org.rootcellar.desktop $out/share/plasma/look-and-feel/
    '';
  };

  # Waits for the WSLg window to map (KWin creates it asynchronously)
  # and maximizes it through the same windowctl path the waybar buttons
  # use. Cosmetic only: never wedges the session unit on failure.
  cellar-kwin-poststart = pkgs.writeShellScriptBin "cellar-kwin-poststart" ''
    set -Eeuo pipefail
    for _ in $(seq 1 30); do
      if /etc/cellar/cellar maximize >/dev/null 2>&1; then
        exit 0
      fi
      sleep 1
    done
    echo "cellar-kwin-poststart: compositor window never appeared" >&2
    exit 0
  '';

  # Applet providers loaded at runtime through KPackage (plasma-desktop's
  # desktop containment, kdeplasma-addons' notes/weather/…): nixpkgs moves
  # their QML plugins into the owning package's lib/qt-6/qml tree, and
  # neither is a build-time dep of plasma-workspace — so neither lands in
  # the wrapped import path and every applet of theirs dies with "module
  # … is not installed" (round 7). Prepended ahead of the wrapper's own
  # dirs so KPackage-loaded applets resolve their private modules.
  runtimeQmlPath = lib.makeSearchPath "lib/qt-6/qml" [
    pkgs.kdePackages.plasma-desktop
    pkgs.kdePackages.kdeplasma-addons
    pkgs.kdePackages.plasma-pa
  ];

  # The Nix C-binary wrapper for startplasma-wayland sets
  # NIXPKGS_QT6_QML_IMPORT_PATH but never copies it to the
  # QML2_IMPORT_PATH that Qt's QML engine actually reads.  Without it
  # every KDE QML module is invisible — plasmashell renders a black
  # screen and every applet fails with "module breeze is not installed".
  # This wrapper bridges the gap: reads the paths the Nix wrapper
  # prepared, exports them where Qt expects, then execs the real binary.
  cellar-kwin-env = pkgs.writeShellScriptBin "cellar-kwin-env" ''
    export NIXPKGS_QT6_QML_IMPORT_PATH="${runtimeQmlPath}''${NIXPKGS_QT6_QML_IMPORT_PATH:+:$NIXPKGS_QT6_QML_IMPORT_PATH}"
    export QML2_IMPORT_PATH="$NIXPKGS_QT6_QML_IMPORT_PATH"
    exec ${pkgs.kdePackages.plasma-workspace}/bin/startplasma-wayland "$@"
  '';

    # One-shot first-run theming. Guarded by a marker so it applies the
    # RootCellar look exactly once (including over an existing unthemed
    # first boot from before the seed existed) and never fights the
    # user's own System Settings choices afterwards. Each apply is
    # wrapped in timeout: kwin-headless is ordered After this unit, so
    # a hung plasma-apply would delay the session by the service
    # timeout — bounded at 60s per tool instead of the default 90s, and
    # the marker is still written on guarded failure.
    cellar-plasma-seed = pkgs.writeShellScriptBin "cellar-plasma-seed" ''
      set -Eeuo pipefail
      cfg="$HOME/.config"
      marker="$cfg/cellar/plasma-seeded"
      [ -e "$marker" ] && exit 0
      echo "cellar-plasma-seed: applying the RootCellar theme"
      mkdir -p "$cfg/kdedefaults"
      printf 'org.rootcellar.desktop\n' > "$cfg/kdedefaults/package"
      # The explicit applies make the rice land without waiting for a
      # reboot; the kdedefaults/package above covers fresh installs.
      timeout 60 plasma-apply-lookandfeel -a org.rootcellar.desktop \
        || echo "cellar-plasma-seed: lookandfeel apply deferred to next boot"
      timeout 60 plasma-apply-cursortheme Bibata-Modern-Ice || true
      # Wallpaper intentionally NOT here: plasma-apply-wallpaperimage
      # talks to plasmashell over D-Bus and can never succeed before the
      # session exists. cellar-plasma-wallpaper owns it, post-session.
      mkdir -p "$(dirname "$marker")"
      touch "$marker"
    '';

  # Wallpaper applies only once plasmashell answers on D-Bus — the tool
  # is a live-control wrapper, not a config writer. Marker-guarded
  # separately from the seed; idempotent. Failing exits non-zero so the
  # unit lands in "failed" rather than "active (exited)" — with
  # RemainAfterExit and a zero exit, a session that never came up would
  # pin the unit as done forever and deploys could never re-trigger it.
  cellar-plasma-wallpaper = pkgs.writeShellScriptBin "cellar-plasma-wallpaper" ''
    set -Eeuo pipefail
    marker="$HOME/.config/cellar/plasma-wallpaper-set"
    [ -e "$marker" ] && exit 0
    [ -f /etc/cellar/sway/bg.jpg ] || exit 0
    for _ in $(seq 1 60); do
      if timeout 30 plasma-apply-wallpaperimage /etc/cellar/sway/bg.jpg; then
        mkdir -p "$(dirname "$marker")"
        touch "$marker"
        exit 0
      fi
      sleep 2
    done
    echo "cellar-plasma-wallpaper: plasmashell never answered" >&2
    exit 1
  '';
in

{
  options.cellar.plasma.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Enable the KDE Plasma 6 desktop (nested in WSLg). Mutually exclusive with webtop (labwc).";
  };

  config = lib.mkIf cfg.plasma.enable {
    # ── Mutual exclusion ────────────────────────────────────────────
    # Only one compositor can own the WSLg window.  Enabling plasma
    # disables webtop; the reverse is enforced by webtop.nix (it does not
    # gate on plasma, but the two modules must not both be true).
    cellar.webtop.enable = lib.mkForce false;

    # ── Plasma 6 module ─────────────────────────────────────────────
    services.desktopManager.plasma6.enable = true;

    # The plasma6 module configures SDDM (package, theme, wayland) but
    # does not set enable=true — force it off regardless: WSLg's Weston
    # is the compositor, and no display manager is needed.
    services.displayManager.sddm.enable = lib.mkForce false;
    services.displayManager.defaultSession = lib.mkForce "plasma";

    # ── System packages ─────────────────────────────────────────────
    environment.systemPackages = with pkgs; [
      kdePackages.konsole # default terminal
      kdePackages.dolphin # file manager
      kdePackages.kate    # text editor
      kdePackages.kcalc   # calculator

      # Icons + theming (bibata/papirus live here, not webtop.nix —
      # plasma disables webtop, so it must carry its own theme stack).
      kdePackages.breeze-icons
      kdePackages.breeze
      kdePackages.breeze-gtk
      bibata-cursors
      papirus-icon-theme
      cellar-plasma-theme

      # Menus + capture tools the cellar verbs drive (cellar menu/store/
      # resize/extend pickers, clipboard, screenshot). webtop.nix ships
      # the same set for labwc; plasma force-disables webtop and must
      # carry its own. fuzzel renders fine on KWin (layer-shell), and
      # its config is already deployed unguarded at /etc/xdg/fuzzel.
      fuzzel
      cliphist
      grim
      slurp

      # Plasma-native app set (apps.toml plasma= entries) + notify-send
      # so launch_gui can report missing tools on the desktop itself.
      kdePackages.gwenview
      kdePackages.ark
      libnotify

      # RootCellar Control Center: Qt6/QML package manager, flake viewer,
      # rebuild with live progress, and settings. GTK4 cellar-software-center
      # stays in webtop (labwc, webtop.nix); this is the Plasma-native replacement.
      rootcellar-control-center
    ];

    # PipeWire is enabled by the plasma6 module, but its socket unit is
    # never activated in this setup — plasmashell's media monitor then
    # spams "Failed to connect to PipeWire" every 5s. Pull the socket
    # in at user-manager start like a graphical machine would.
    systemd.user.sockets.pipewire.wantedBy = [ "default.target" ];

    # XDG_DATA_DIRS for every user unit. The wrapped plasmashell only
    # prefixes its own store deps; without the system profile in the
    # search path, ksycoca sees no applications/*.desktop (the launcher
    # comes up empty and kicker logs invalid entries) and plasma-desktop's
    # QML applet modules (activityswitcher, pager, folder) fail to load.
    # environment.d feeds the user manager itself, so all units inherit;
    # daemon-reload re-runs the generator, making it live on deploy.
    # PATH as well: fuzzel/kate/dolphin from user units missed the system
    # profile and failed with "command not found" / exit 127.
    environment.etc."environment.d/10-cellar-xdg-data-dirs.conf".text = ''
      XDG_DATA_DIRS=/run/current-system/sw/share
      PATH=/run/current-system/sw/bin''${PATH:+:$PATH}
    '';

    # Clean teardown: plasmashell and kded6 ship Restart=on-failure, so
    # when the session stops they die, restart without a compositor,
    # fail Qt platform init and SIGABRT-loop with drkonqi dialogs. Bind
    # them to the session unit and stop restarting them outside it.
    systemd.user.services = {
      plasma-plasmashell = {
        overrideStrategy = lib.mkForce "asDropin";
        unitConfig.PartOf = [ "kwin-headless.service" ];
        serviceConfig.Restart = lib.mkForce "no";
      };
      plasma-kded6 = {
        overrideStrategy = lib.mkForce "asDropin";
        unitConfig.PartOf = [ "kwin-headless.service" ];
        serviceConfig.Restart = lib.mkForce "no";
      };
    };

    # Sound: WSLg exposes a PulseAudio server (RDP audio). libpulse
    # clients honour PULSE_SESSION/…PULSE_SERVER ahead of everything
    # else, so playback lands on the Windows side. sessionVariables
    # (not variables) is what reaches systemd user services.
    environment.sessionVariables.PULSE_SERVER = "unix:/mnt/wslg/PulseServer";

    # D-Bus-activated launchers need the system profile on PATH.
    # NixOS pins every user service's PATH to a minimal store default
    # (coreutils, findutils, grep, sed, systemd) via per-unit drop-in
    # Environment=PATH=, which beats environment.d. Two proven victims:
    # dbus (klauncher6 is D-Bus-activated and inherits the bus env) and
    # plasma-plasmashell, whose in-process KIO launches (systemsettings
    # from kickoff/taskbar) died with "Could not find the program".
    # Giving both units config.system.path puts sw/bin first while
    # keeping the NixOS defaults behind it.
    systemd.user.services.dbus.path = [ config.system.path ];
    systemd.user.services.plasma-plasmashell.path = [ config.system.path ];

    # ── Qt theming ──────────────────────────────────────────────────
    # Breeze for Qt, Papirus for icons, catppuccin accent.
    environment.variables = {
      QT_QPA_PLATFORM = "wayland";
      QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
      XCURSOR_THEME = "Bibata-Modern-Ice";
      XCURSOR_SIZE = "24";
      # Portal integration: KDE portals for file dialogs.
      XDG_CURRENT_DESKTOP = "KDE";
    };

    # ── KWin config seed ─────────────────────────────────────────────
    # Only the virtual-desktop count.  Compositing knobs live in the
    # service environment (KWIN_COMPOSE); an earlier [Common]
    # CompositingMode entry was guessed syntax and never did anything.
    # Deployed under /etc/xdg/cellar — /etc/cellar itself is a single
    # directory symlink (cellarConfigs) and cannot take per-file
    # entries.  Seeded into the user's kwinrc on first run only (see
    # activation below), never clobbering System Settings edits.
    environment.etc."xdg/cellar/plasma-kwinrc".text = ''
      [Desktops]
      Number=5

      # Software-rendered compositing pays per enabled effect; blur is
      # the expensive one and earns nothing on an RDP stream.
      [Plugins]
      blurEnabled=false
    '';

    # ── Systemd user service: kwin_wayland on WSLg ──────────────────
    # startplasma-wayland is the standard Plasma session entry point.
    # In WSLg it runs as a Wayland client of Weston (wayland-0) and
    # the desktop appears as a native Windows window — same model as
    # the labwc-headless service.
    systemd.user.services.kwin-headless = {
      description = "KDE Plasma 6 desktop (nested in WSLg Weston)";
      wantedBy = [ "default.target" ];
      after = [ "wslg-x11-sockets.service" "cellar-plasma-seed.service" ];
      startLimitIntervalSec = 0;
      serviceConfig = {
        Type = "simple";
        # cellar-kwin-env bridges NIXPKGS_QT6_QML_IMPORT_PATH → QML2_IMPORT_PATH
        # so Qt's QML engine finds KDE modules (breeze, plasma, kirigami…).
        ExecStart = "${cellar-kwin-env}/bin/cellar-kwin-env";
        # Maximize the WSLg window once it maps (labwc opened fullscreen
        # through the same windowctl path; without this plasma starts
        # as a small floating window). No menu open here: ExecStartPost
        # races plasmashell and inherits WAYLAND_DISPLAY=wayland-0
        # (Weston), so fuzzel opens on the wrong compositor. Menu
        # autostart is an XDG seed — see plasma-setup activation.
        ExecStartPost = [
          "${cellar-kwin-poststart}/bin/cellar-kwin-poststart"
        ];
        Restart = "on-failure";
        RestartSec = 3;
      };
      environment.PATH = lib.mkForce "/run/current-system/sw/bin";
      environment = {
        DISPLAY = ":0";
        WAYLAND_DISPLAY = "wayland-0";
        XDG_RUNTIME_DIR = "/run/user/${toString cfg.uid}";
        # KDE session identifiers — portals and D-Bus services look for these.
        XDG_CURRENT_DESKTOP = "KDE";
        XDG_SESSION_TYPE = "wayland";
        XDG_SESSION_DESKTOP = "KDE";
        # Cursor theme for KDE and child apps.
        XCURSOR_THEME = "Bibata-Modern-Ice";
        XCURSOR_SIZE = "24";
        # Qt on Wayland.
        QT_QPA_PLATFORM = "wayland";
        QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
        # No GPU in WSL2, but "software" has two speeds: KWIN_COMPOSE=O2
        # composites through OpenGL-over-llvmpipe, which parallelizes
        # across cores and measurably beats the QPainter raster path
        # ("Q") on a 16-thread box. Q was the earlier guess for session
        # sluggishness; the real culprit was CPU/memory starvation from
        # co-resident workloads. If a future kwin fails EGL init, it
        # falls back on its own; revert to "Q" only if the session comes
        # up garbled.
        KWIN_COMPOSE = "O2";
        # Breeze icons + GTK theme coherence.
        GTK_THEME = "catppuccin-frappe-blue-standard";
      };
    };

    # ── Mask plasma services that cannot live in WSL ────────────────
    # Crash-loop diagnosis in PLAN-PLASMA.md.  enable=false on a
    # foreign unit generates a /dev-null symlink in /etc/systemd/user,
    # which outranks the package unit paths — systemd's native mask.
    systemd.user.units = {
      "plasma-powerdevil.service".enable = false; # no power stack in a VM
      "plasma-polkit-agent.service".enable = false; # aborts; sudo is terminal-side
      "plasma-baloorunner.service".enable = false; # file indexer = CPU waste
    };

    # ── First-run theming service ───────────────────────────────────
    # Applies the RootCellar look-and-feel once (marker-guarded), before
    # the session starts. See the let bindings for the guard rules.
    systemd.user.services.cellar-plasma-seed = {
      description = "Seed the RootCellar Plasma theming (once)";
      wantedBy = [ "default.target" ];
      before = [ "kwin-headless.service" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${cellar-plasma-seed}/bin/cellar-plasma-seed";
        RemainAfterExit = true;
      };
      environment.PATH = lib.mkForce "/run/current-system/sw/bin";
      environment = {
        QT_QPA_PLATFORM = "offscreen";
        XDG_RUNTIME_DIR = "/run/user/${toString cfg.uid}";
        # plasma-apply-* resolve KPackages through XDG_DATA_DIRS, which a
        # bare user service does not inherit from the profile.
        XDG_DATA_DIRS = "/run/current-system/sw/share";
      };
    };

    # ── Wallpaper service ───────────────────────────────────────────
    # Runs after the session; waits (up to ~3 min) for plasmashell to
    # answer D-Bus — under llvmpipe the shell takes a while to come up.
    systemd.user.services.cellar-plasma-wallpaper = {
      description = "Set the cellar wallpaper once plasmashell is up";
      wantedBy = [ "default.target" ];
      after = [ "kwin-headless.service" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${cellar-plasma-wallpaper}/bin/cellar-plasma-wallpaper";
        RemainAfterExit = true;
      };
      environment.PATH = lib.mkForce "/run/current-system/sw/bin";
      environment = {
        QT_QPA_PLATFORM = "wayland";
        XDG_RUNTIME_DIR = "/run/user/${toString cfg.uid}";
        XDG_DATA_DIRS = "/run/current-system/sw/share";
      };
    };

    # ── Activation: config seeds + ksycoca ──────────────────────────
    # Write-once seeds (never clobbering System Settings edits) plus
    # stale ksycoca cleanup. The screen locker must stay off in this
    # nested session: WSLg's RDP layer fires suspend/resume when the
    # window loses focus, kwin honours LockOnResume, and the greeter's
    # PAM auth is unreliable in WSL — the desk locked itself on first
    # focus loss and the password was rejected.
    system.userActivationScripts.plasma-setup = ''
      export PATH="/run/current-system/sw/bin:$PATH"
      mkdir -p "$HOME/.config"
      if [ ! -f "$HOME/.config/kwinrc" ]; then
        cp /etc/xdg/cellar/plasma-kwinrc "$HOME/.config/kwinrc"
      fi
      # kwin must be able to write its own config; the seed above lives in
      # the read-only store and cp preserved that mode (0444), which kwin
      # logged as "Couldn't create a new file ... not writable".
      chmod u+rw "$HOME/.config/kwinrc" 2>/dev/null || true
      if [ ! -f "$HOME/.config/kscreenlockerrc" ]; then
        printf '[Daemon]\nAutolock=false\nLockOnResume=false\nTimeout=0\n' \
          > "$HOME/.config/kscreenlockerrc"
      fi
      # ── Shortcuts (KService-launched, absolute Exec) ───────────────
      # kglobalacceld (inside KWin on Plasma 6 Wayland) reads services
      # entries from kglobalshortcutsrc at session init. The container
      # group name is matched case-sensitively and must be lower-case
      # "services" (kglobalacceld 6.3.6 globalshortcutsregistry.cpp:662):
      # an upper-case [Services] group falls through to the regular
      # component loader, becomes a bogus component, and is pruned on
      # the daemon's next save. Each entry must reference a KService
      # .desktop it can resolve — the four targets ship under both
      # share/applications and share/kglobalaccel (see deskbottom.nix),
      # so the Exec comes from there. _launch is Shortcut,Default,Name;
      # the first field is the shortcut, never the binary.
      # Rewrite every activation: the old range delete ate the next
      # section header and the marker let stale entries live forever.
      KGSRC="$HOME/.config/kglobalshortcutsrc"
      touch "$KGSRC"
      for s in cellar-menu cellar-extend-next cellar-extend-prev rootcellar-control-center; do
        # Purge both spellings: drop [$c][$s.desktop] through the line
        # before the next [ header, keeping that header (awk one-pass).
        for c in Services services; do
          awk -v sect="[''${c}][''${s}.desktop]" '
            BEGIN { skip=0 }
            $0 == sect { skip=1; next }
            skip && /^\[/ { skip=0 }
            skip { next }
            { print }
          ' "$KGSRC" > "$KGSRC.tmp" && mv "$KGSRC.tmp" "$KGSRC"
        done
      done
      cat >> "$KGSRC" <<'EOF'

[services][cellar-menu.desktop]
_launch=Ctrl+Alt+Space,Ctrl+Alt+Space,RootCellar Menu

[services][cellar-extend-next.desktop]
_launch=Ctrl+Alt+E,Ctrl+Alt+E,Cellar Extend Next Monitor

[services][cellar-extend-prev.desktop]
_launch=Ctrl+Alt+Shift+E,Ctrl+Alt+Shift+E,Cellar Extend Previous Monitor

[services][rootcellar-control-center.desktop]
_launch=Ctrl+Alt+C,Ctrl+Alt+C,RootCellar Control Center
EOF
      # ── Desktop icon ────────────────────────────────────────────
      # A launcher on ~/Desktop so the menu is one double-click away
      # even without knowing keybinds. Write-once: never clobber.
      mkdir -p "$HOME/Desktop"
      if [ ! -f "$HOME/Desktop/cellar-menu.desktop" ]; then
        cat > "$HOME/Desktop/cellar-menu.desktop" <<'DTEOF'
[Desktop Entry]
Type=Application
Name=RootCellar Menu
GenericName=Start menu
Exec=/run/current-system/sw/bin/cellar menu
Icon=video-display
Terminal=false
Categories=Utility;System;
Keywords=cellar;menu;screen;resize;monitor;
DTEOF
        chmod +x "$HOME/Desktop/cellar-menu.desktop"
      fi
      # ── Menu on session start (XDG autostart) ───────────────────
      # plasmashell reads autostart after the session exists (correct
      # wayland-0 socket, shell-ready). Write-once: never clobber a
      # user edit. Replaces the ExecStartPost race (wrong WAYLAND_DISPLAY).
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
      # ── Pin to taskbar (quicklaunch) ────────────────────────────
      # Add a quicklaunch applet with the RootCellar Menu to the
      # bottom panel so it sits beside the kickoff icon. Marker-
      # guarded; AppletOrder updated so Plasma renders it.
      PANEL_CFG="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
      PIN_MARKER="$HOME/.config/cellar/pinned-menu"
      if [ -f "$PANEL_CFG" ]; then
        # Heal older seeds: Plasma 6 quicklaunch reads launcherUrls=,
        # not apps= (wrong key from an earlier pin implementation).
        sed -i '/apps=.*cellar-menu\.desktop/d' "$PANEL_CFG" 2>/dev/null || true
        if [ ! -f "$PIN_MARKER" ] && ! grep -q 'cellar-menu.desktop' "$PANEL_CFG" 2>/dev/null; then
          NEXT_ID=$(($(grep -oP '\[Containments\]\[20\]\[Applets\]\[\K[0-9]+' "$PANEL_CFG" 2>/dev/null | sort -n | tail -1) + 1))
          cat >> "$PANEL_CFG" <<PALEOF

[Containments][20][Applets][''${NEXT_ID}]
immutability=1
plugin=org.kde.plasma.quicklaunch

[Containments][20][Applets][''${NEXT_ID}][Configuration]
PreloadWeight=100

[Containments][20][Applets][''${NEXT_ID}][Configuration][General]
launcherUrls=file:///run/current-system/sw/share/applications/cellar-menu.desktop
PALEOF
          sed -i "s/^\(AppletOrder=.*\)$/\1;''${NEXT_ID}/" "$PANEL_CFG"
          mkdir -p "$(dirname "$PIN_MARKER")"
          touch "$PIN_MARKER"
        fi
      fi
      # Clear stale ksycoca so Plasma picks up new packages.
      rm -f "$HOME/.cache/ksycoca"*
    '';
  };
}
