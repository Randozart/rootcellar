# KDE Plasma 6 desktop, nested inside WSLg's Weston compositor.
# Mutually exclusive with the sway desktop (webtop.nix): enabling plasma
# disables webtop so only one compositor runs at a time.
#
# KWin becomes a Wayland client of WSLg's Weston on wayland-0 — the same
# model sway uses.  SDDM is forcibly disabled: WSLg owns the display
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
    description = "Enable the KDE Plasma 6 desktop (nested in WSLg). Mutually exclusive with webtop (sway).";
  };

  config = lib.mkIf cfg.plasma.enable {
    # ── Mutual exclusion ────────────────────────────────────────────
    # Only one compositor can own the WSLg window.  Enabling plasma
    # disables sway; the reverse is enforced by webtop.nix (it does not
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
      # the same set for sway; plasma force-disables webtop and must
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
      # stays in sway (webtop.nix); this is the Plasma-native replacement.
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
    environment.etc."environment.d/10-cellar-xdg-data-dirs.conf".text =
      "XDG_DATA_DIRS=/run/current-system/sw/share\n";

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
    '';

    # ── Systemd user service: kwin_wayland on WSLg ──────────────────
    # startplasma-wayland is the standard Plasma session entry point.
    # In WSLg it runs as a Wayland client of Weston (wayland-0) and
    # the desktop appears as a native Windows window — same model as
    # the sway-headless service.
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
        # Maximize the WSLg window once it maps (sway opened fullscreen
        # through the same windowctl path; without this plasma starts
        # as a small floating window).
        ExecStartPost = "${cellar-kwin-poststart}/bin/cellar-kwin-poststart";
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
        # No GPU in WSL2 (software-only).  KWIN_COMPOSE=Q forces KWin's
        # QPainter software compositor instead of OpenGL-over-llvmpipe,
        # which is where the session's sluggishness concentrated.
        KWIN_COMPOSE = "Q";
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
      mkdir -p "$HOME/.config"
      if [ ! -f "$HOME/.config/kwinrc" ]; then
        cp /etc/xdg/cellar/plasma-kwinrc "$HOME/.config/kwinrc"
      fi
      if [ ! -f "$HOME/.config/kscreenlockerrc" ]; then
        printf '[Daemon]\nAutolock=false\nLockOnResume=false\nTimeout=0\n' \
          > "$HOME/.config/kscreenlockerrc"
      fi
      # The three shortcuts with no mouse-native home (menu + monitor
      # moves). Plasma 6.3 handles shortcuts inside kwin — the
      # kglobalaccel daemon unit stays dead — and kwin resolves
      # [Services] entries against share/kglobalaccel desktop files
      # (deployed with the cellar). Append-once: never touches user
      # edits; kwin re-reads the file when deploy bounces the session.
      # Bracket keys avoided: their kglobalaccel names are ambiguous,
      # these parse as plain Qt portable strings.
      if ! grep -q '^\[Services\]\[cellar-menu.desktop\]' \
        "$HOME/.config/kglobalshortcutsrc" 2>/dev/null; then
        cat >> "$HOME/.config/kglobalshortcutsrc" <<'EOF'

[Services][cellar-menu.desktop]
_launch=Ctrl+Alt+Space,Ctrl+Alt+Space,RootCellar Menu

[Services][cellar-extend-next.desktop]
_launch=Ctrl+Alt+E,Ctrl+Alt+E,Cellar Extend Next Monitor

[Services][cellar-extend-prev.desktop]
_launch=Ctrl+Alt+Shift+E,Ctrl+Alt+Shift+E,Cellar Extend Previous Monitor

[Services][rootcellar-control-center.desktop]
_launch=Ctrl+Alt+C,Ctrl+Alt+C,RootCellar Control Center
EOF
      fi
      # Clear stale ksycoca so Plasma picks up new packages.
      rm -f "$HOME/.cache/ksycoca"*
    '';
  };
}
