# KDE Plasma 6 desktop, nested inside WSLg's Weston compositor.
# Mutually exclusive with the sway desktop (webtop.nix): enabling plasma
# disables webtop so only one compositor runs at a time.
#
# KWin becomes a Wayland client of WSLg's Weston on wayland-0 — the same
# model sway uses.  SDDM is forcibly disabled: WSLg owns the display
# lifecycle, so no display manager is needed.
#
# The Ctrl+Alt modifier constraint applies here too (WSLg sends Win to
# Windows, not the guest — see PLAN-KEYBINDS.md).  KDE's defaults are
# Super-heavy; a kwinrc snippet remaps the most common ones.
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
      kdePackages.sddm    # needed for session registration (not as display mgr)

      # Qt theming for GTK-style coherence.
      kdePackages.breeze-icons
      kdePackages.breeze-qt5
      kdePackages.breeze-gtk

      # Clipboard history in KDE.
      kdePackages.klipper
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

    # ── KWin Ctrl+Alt remapping ─────────────────────────────────────
    # KDE's default shortcuts all use Super, which WSLg sends to
    # Windows.  Remap the most-used ones to Ctrl+Alt so the desk is
    # usable without leaving the keyboard.  Written to the user's
    # kwinrc at activation time.
    environment.etc."cellar/plasma-kwinrc".text = ''
      [ModifierOnlyShortcuts]
      Meta=none

      [Desktops]
      Number=5

      [Common]
      CompositingMode=0
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
        # Breeze icons + GTK theme coherence.
        QT_STYLE_OVERRIDE = "breeze";
        GTK_THEME = "catppuccin-frappe-blue-standard";
      };
    };

    # ── Activation: kwinrc remap + ksycoca ──────────────────────────
    system.userActivationScripts.plasma-setup = ''
      # Link the Ctrl+Alt kwinrc snippet into the user's config.
      mkdir -p "$HOME/.config"
      if [ -f /etc/cellar/plasma-kwinrc ]; then
        cp /etc/cellar/plasma-kwinrc "$HOME/.config/kwinrc"
      fi
      # Clear stale ksycoca so Plasma picks up new packages.
      rm -f "$HOME/.cache/ksycoca"*
    '';
  };
}
