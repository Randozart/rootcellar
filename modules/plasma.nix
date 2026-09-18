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
    ];

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
      after = [ "wslg-x11-sockets.service" ];
      startLimitIntervalSec = 0;
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.kdePackages.plasma-workspace}/bin/startplasma-wayland";
        Restart = "on-failure";
        RestartSec = 3;
      };
      environment.PATH = lib.mkForce "/run/current-system/sw/bin";
      environment = {
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
        QT_STYLE_OVERRIDE = "breeze";
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

    # ── Activation: first-run seed + ksycoca ────────────────────────
    # Idempotent by construction: the theming block only runs while
    # ~/.config/kdeglobals is absent, so it can never fight the user's
    # own System Settings choices after the first boot.  The kwinrc
    # seed is likewise write-once; the earlier version cp-overwrote it
    # on every activation and would have clobbered settings edits.
    system.userActivationScripts.plasma-setup = ''
      mkdir -p "$HOME/.config"
      if [ ! -f "$HOME/.config/kwinrc" ]; then
        cp /etc/xdg/cellar/plasma-kwinrc "$HOME/.config/kwinrc"
      fi
      if [ ! -f "$HOME/.config/kdeglobals" ]; then
        echo "plasma-setup: seeding first-run theming"
        # kdedefaults/package points startplasma at the look-and-feel to
        # apply natively on first boot — full theming without any
        # headless Qt tooling.
        mkdir -p "$HOME/.config/kdedefaults"
        printf 'org.kde.breezedark.desktop\n' > "$HOME/.config/kdedefaults/package"
        # Cursor theme (real key: kcminputrc [Mouse] cursorTheme).
        printf '[Mouse]\ncursorTheme=Bibata-Modern-Ice\n' > "$HOME/.config/kcminputrc"
        # Wallpaper: the long-standing cellar default.  The tool may
        # refuse to run without a session — guarded, fixable later via
        # right-click → Configure Desktop.
        if [ -f /etc/cellar/sway/bg.jpg ]; then
          QT_QPA_PLATFORM=offscreen \
            "${pkgs.kdePackages.plasma-workspace}/bin/plasma-apply-wallpaperimage" \
            /etc/cellar/sway/bg.jpg >/dev/null 2>&1 || \
            echo "plasma-setup: wallpaper seed skipped (no session)"
        fi
      fi
      # Clear stale ksycoca so Plasma picks up new packages.
      rm -f "$HOME/.cache/ksycoca"*
    '';
  };
}
