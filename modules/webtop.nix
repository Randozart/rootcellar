# Sway desktop rendered natively via WSLg nesting.
# sway connects to WSLg's Weston compositor (wayland-0) and the desktop
# appears as a native Windows window — no encoding, no browser stream.
# waybar runs as a sway client on the layer-shell protocol. The
# cellar-output-watch service re-creates the window if Weston closes it
# (xdg close destroys wlroots' nested output). See PLAN-HYPRDESK.md.
{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.cellar;

  # When WSLg's Weston sends an xdg close to sway's window (RDP session
  # wake/reconfigure, window closed, monitor change), wlroots' Wayland
  # backend destroys the output and never re-creates it: sway keeps
  # running but renders nothing — a frozen desktop with no bar. This
  # watchdog notices the zero-output state and runs `swaymsg
  # create_output`, which on the Wayland backend opens a fresh
  # xdg_toplevel on Weston (a new window). Only if that fails while
  # the sway service is still active does it fall back to a restart.
  cellar-output-watch = pkgs.writeShellScriptBin "cellar-output-watch" ''
    set -Eeuo pipefail
    runtime="/run/user/${toString cfg.uid}"
    while true; do
      sleep 5
      sock="$(ls "$runtime"/sway-ipc.*.sock 2>/dev/null | head -1 || true)"
      [[ -z "$sock" ]] && continue
      count="$(SWAYSOCK="$sock" swaymsg -t get_outputs 2>/dev/null | grep -c '"name"' || true)"
      if [[ "$count" == "0" ]]; then
        echo "cellar-output-watch: sway has no outputs; recreating window"
        if SWAYSOCK="$sock" swaymsg create_output >/dev/null 2>&1; then
          # The window's destruction took its terminal with it (foot exits
          # when its surface dies). Re-dock the shared zellij session so the
          # desktop comes back with a terminal, not just waybar and a
          # wallpaper. Only if foot is already gone: recovery while a foot
          # survived would spawn a duplicate client.
          sleep 1
          if ! pgrep -x foot >/dev/null 2>&1; then
            echo "cellar-output-watch: relaunching dock (foot + zellij)"
            # cellar-desk, not cellar: the desktop's own session renders
            # at its own size instead of the smallest attached client.
            SWAYSOCK="$sock" swaymsg exec "foot -e zellij attach cellar-desk --create" >/dev/null 2>&1 || true
          fi
        else
          # Only a hard restart if sway is genuinely alive but stuck:
          # a deliberate sway exit must stay dead.
          if systemctl --user is-active --quiet sway-headless; then
            echo "cellar-output-watch: create_output failed; restarting sway"
            systemctl --user restart sway-headless
          fi
        fi
      fi
    done
  '';
in

{
  options.cellar.webtop.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Install the desktop stack (WSLg-nested sway, waybar, GUI apps). Disable on lean machines — the terminal deskbottom is unaffected.";
  };

  config = lib.mkIf cfg.webtop.enable {
    environment.systemPackages = with pkgs; [
    # Tiling WM + app suite — terminal-heavy desktop
    sway
    swww # wallpaper daemon: rotation, transitions, random picker
    waybar # top panel: menu, workspaces, taskbar, window controls, clock
    foot # wayland-native terminal (docks the Zellij session)
    fuzzel # launcher + action menus: reads /etc/xdg natively, icons by theme name
    wofi # safety net while fuzzel proves out (fuzzel is Wayland-only; wofi can fall back to X)
    wl-clipboard # Ctrl+C/V between kiosk and terminal
    firefox
    chromium

    # Convenient-desktop layer (docs/CONVENIENT-DESKTOP.md): GUI apps so
    # the cellar reads as a regular desktop, not just a terminal.
    nautilus # files
    gnome-text-editor # editor
    gnome-calculator
    gnome-system-monitor
    gnome-control-center # settings
    loupe # image viewer
    file-roller # archives

    # Desktop services: notifications, clipboard history, screenshots.
    mako
    cliphist
    grim
    slurp

    # Portals: file dialogs and screenshots for GTK apps (the logs showed
    # org.freedesktop.portal.Desktop missing without these).
    xdg-desktop-portal
    xdg-desktop-portal-gtk

    # Theme: icons for fuzzel/taskbar, cursors for sway and every app, and
    # a GTK theme so the GUI apps read as a coherent desktop.
    papirus-icon-theme
    bibata-cursors
    catppuccin-gtk

    # nwg-shell components: the app grid (drawer). The full categorized start
    # menu (nwg-menu) was dropped as redundant — the ≡ hamburger's `cellar
    # menu` covers it.
    nwg-drawer
    autotiling # auto-split along the longer edge
    cellar-software-center # visual package manager (Ctrl+Alt+S)
  ];

  # XDG desktop portal: GTK apps get native file dialogs and screenshots.
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  # GTK settings so the GUI apps read as one coherent desktop: catppuccin
  # for GTK3, Papirus icons everywhere, dark preference for libadwaita.
  environment.etc."xdg/gtk-3.0/settings.ini".text = ''
    [Settings]
    gtk-theme-name=catppuccin-frappe-blue-standard
    gtk-icon-theme-name=Papirus-Dark
    gtk-application-prefer-dark-theme=1
  '';
  environment.etc."xdg/gtk-4.0/settings.ini".text = ''
    [Settings]
    gtk-icon-theme-name=Papirus-Dark
    gtk-application-prefer-dark-theme=1
  '';

  # WSLg mounts /tmp/.X11-unix read-only and without the sticky bit, which
  # makes XWayland abort ("sticky bit not set"). Recreate the directory
  # writable; the compositor then owns display :0 inside the cellar
  # (WSLg's X server stays reachable in its own namespace at /mnt/wslg).
  #
  # NixOS-WSL also ships a mount unit for /tmp/.X11-unix/X0 that conflicts
  # with our recreation — disable it; our service handles the socket.
  systemd.units."tmp-.X11\\x2dunix-X0.mount".enable = lib.mkForce false;

  systemd.services.wslg-x11-sockets = {
    description = "Recreate /tmp/.X11-unix writable for XWayland";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-tmpfiles-setup.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "wslg-x11-sockets" ''
        set -euo pipefail
        um() { ${pkgs.util-linux}/bin/umount "$1" 2>/dev/null || true; }
        um /tmp/.X11-unix/X0
        um /tmp/.X11-unix
        ${pkgs.coreutils}/bin/rm -rf /tmp/.X11-unix
        ${pkgs.coreutils}/bin/mkdir -m 1777 /tmp/.X11-unix
      '';
    };
  };

  # Enable lingering so user services boot at distro start, not just
  # when a terminal session opens. Without this, the webtop stack only
  # runs after you log in — defeating the "always available" goal.
  systemd.tmpfiles.rules = [
    "d /var/lib/systemd/linger 0755 root root -"
    "f /var/lib/systemd/linger/${cfg.user} 0644 root root -"
  ];

  # Systemd user services for the headless desktop stack.
  systemd.user.services = {
    sway-headless = {
      description = "Sway compositor (nested in WSLg Weston)";
      wantedBy = [ "default.target" ];
      after = [ "wslg-x11-sockets.service" ];
      # Spaced, unlimited retries: default 100ms restarts hit systemd's
      # 5-failure rate limit in ~3s and the stack stays dead until a
      # human intervenes. 2s spacing outlives transient races instead.
      startLimitIntervalSec = 0;
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.sway}/bin/sway -c /etc/cellar/sway/config";
        Restart = "on-failure";
        RestartSec = 2;
      };
      # The user manager's PATH lacks the system profile, so sway's exec
      # lines (foot, firefox, wofi) all died with ENOENT. The NixOS `path`
      # option treats entries as packages (appending /bin), which mangled
      # the profile dir into .../bin/bin, and the module system already
      # defines environment.PATH itself — hence mkForce. The system
      # profile alone carries sh, foot, firefox and wofi.
      environment.PATH = lib.mkForce "/run/current-system/sw/bin";
      environment = {
        # Connect to WSLg's Weston compositor instead of creating a
        # headless output: sway becomes a native Windows window via
        # WSLg's Wayland→DWM bridge. wayland-0 is WSLg's socket;
        # wayland-1 was the old headless output.
        WLR_BACKENDS = "wayland";
        WAYLAND_DISPLAY = "wayland-0";
        WLR_LIBINPUT_NO_DEVICES = "1";
        XDG_RUNTIME_DIR = "/run/user/${toString cfg.uid}";
        # Systemd user units never source the shell profile, where
        # environment.variables sets these: without them the startup
        # foot's zellij runs on default config — a grey, theme-less
        # session — and it CREATES the shared session at boot, so
        # every later attach inherits the defaults.
        ZELLIJ_CONFIG_DIR = "/etc/cellar/zellij";
        CELLAR_APPS = "/etc/cellar/apps.toml";
        # Cursor theme for the compositor and every child app (waybar was
        # logging "Unable to load hand2 from the cursor theme" without it).
        XCURSOR_THEME = "Bibata-Modern-Ice";
        XCURSOR_SIZE = "24";
        # libadwaita apps (nautilus, gnome-system-monitor, the software
        # center) ignore gtk-theme-name from settings.ini and only honour
        # this override — without it they render stock light Adwaita.
        GTK_THEME = "catppuccin-frappe-blue-standard";
      };
    };

    # Weston closes sway's window on RDP session wake/reconfigure;
    # wlroots destroys the output and never re-creates it. The watchdog
    # re-creates the window when sway reports zero outputs.
    cellar-output-watch = {
      description = "Sway output watchdog";
      wantedBy = [ "default.target" ];
      after = [ "sway-headless.service" ];
      startLimitIntervalSec = 0;
      serviceConfig = {
        Type = "simple";
        ExecStart = "${cellar-output-watch}/bin/cellar-output-watch";
        Restart = "always";
        RestartSec = 2;
      };
      environment = {
        XDG_RUNTIME_DIR = "/run/user/${toString cfg.uid}";
        PATH = lib.mkForce "/run/current-system/sw/bin";
      };
    };

    # Headless VNC/websockify/waymote services removed: the native WSLg
    # nesting path replaced the browser-kiosk pipeline entirely, and the
    # disabled waymote-gateway unit was restart-looping in the journal.

    # libadwaita reads palette/translucency overrides from the user's
    # gtk-4.0 css. Ours is a symlink to the deployed file, so it always
    # matches the current system's palette; -sfn replaces exactly this
    # link, never anything else the user keeps in ~/.config.
    cellar-gtk-css = {
      description = "Link the cellar GTK palette into ~/.config/gtk-4.0";
      wantedBy = [ "default.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p %h/.config/gtk-4.0";
        ExecStart =
          "${pkgs.coreutils}/bin/ln -sfn /etc/cellar/gtk/gtk4.css %h/.config/gtk-4.0/gtk.css";
      };
    };
  };
  };
}
