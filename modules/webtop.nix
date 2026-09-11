# Headless XFCE desktop streamed via noVNC.
# Auto-starts at login; accessible from Carbonyl or any browser at :6080.
# Architecture: labwc (headless Wayland) -> wayvnc -> websockify -> noVNC.
{
  pkgs,
  lib,
  ...
}:

{
  environment.systemPackages = with pkgs; [
    # Wayland compositor (headless backend)
    labwc

    # XFCE desktop components
    xfce.xfce4-panel
    xfce.xfce4-settings
    xfce.xfce4-terminal
    xfce.thunar
    xfce.xfce4-appfinder
    xfce.xfce4-taskmanager

    # VNC server + WebSocket proxy + HTML5 client
    wayvnc
    python3Packages.websockify
    novnc
  ];

  # WSLg mounts /tmp/.X11-unix read-only and without the sticky bit, which
  # makes labwc's XWayland abort ("sticky bit not set"). Recreate the
  # directory writable; labwc then owns display :0 inside the cellar
  # (WSLg's X server stays reachable in its own namespace at /mnt/wslg).
  #
  # NixOS-WSL also ships a mount unit for /tmp/.X11-unix/X0 that conflicts
  # with our recreation — disable it; our service handles the socket.
  systemd.units."tmp-.X11\\x2dunix-X0.mount".enable = lib.mkForce false;

  systemd.services.wslg-x11-sockets = {
    description = "Recreate /tmp/.X11-unix writable for labwc XWayland";
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
    "f /var/lib/systemd/linger/randy 0644 root root -"
  ];

  # Systemd user services for the headless desktop stack.
  # These run as the logged-in user and auto-start at login.
  systemd.user.services = {
    labwc-headless = {
      description = "Headless Wayland compositor for desktop streaming";
      wantedBy = [ "default.target" ];
      after = [ "wslg-x11-sockets.service" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.labwc}/bin/labwc";
        Restart = "on-failure";
      };
      environment = {
        WLR_BACKENDS = "headless";
        WLR_LIBINPUT_NO_DEVICES = "1";
        XDG_RUNTIME_DIR = "/run/user/1000";
        WAYLAND_DISPLAY = "wayland-1";
      };
    };

    xfce-session = {
      description = "XFCE desktop session";
      wantedBy = [ "default.target" ];
      after = [ "labwc-headless.service" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.xfce.xfce4-session}/bin/xfce4-session";
        Restart = "on-failure";
      };
      environment = {
        WAYLAND_DISPLAY = "wayland-1";
        XDG_RUNTIME_DIR = "/run/user/1000";
        XDG_CONFIG_DIRS = "/etc/xdg:$HOME/.config";
        DISPLAY = ":0";
      };
    };

    wayvnc = {
      description = "VNC server for headless desktop";
      wantedBy = [ "default.target" ];
      after = [ "labwc-headless.service" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.wayvnc}/bin/wayvnc --output=wayland-1 0.0.0.0 5900";
        Restart = "on-failure";
      };
      environment = {
        XDG_RUNTIME_DIR = "/run/user/1000";
        WAYLAND_DISPLAY = "wayland-1";
      };
    };

    websockify = {
      description = "WebSocket proxy for noVNC";
      wantedBy = [ "default.target" ];
      after = [ "wayvnc.service" ];
      serviceConfig = {
        Type = "simple";
        ExecStart =
          "${pkgs.python3Packages.websockify}/bin/websockify --web=${pkgs.novnc}/share/novnc 6080 localhost:5900";
        Restart = "on-failure";
      };
    };
  };
}
