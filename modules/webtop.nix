# Headless sway desktop streamed via noVNC.
# Nothing autostarts the desktop experience: the compositor runs headless
# (invisible), and the mode begins only when a viewer opens — the Carbonyl
# pane or `cellar overlay`. See PLAN-HYPRDESK.md.
# Architecture: sway (headless) -> wayvnc -> websockify -> noVNC.
#
# Why sway, not Hyprland: aquamarine's allocator needs a DRM node and this
# cellar has none (no /dev/dri, no WSLg compositor, no GPU driver in the
# bore kernel) — Hyprland aborts at CBackend::create(). sway is wlroots
# with pixman software rendering: proven headless in this exact
# environment by the labwc stack it replaces.
{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.cellar;
in

{
  options.cellar.webtop.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Install the headless desktop stack (compositor, VNC, GUI apps). Disable on lean machines — the terminal deskbottom is unaffected.";
  };

  config = lib.mkIf cfg.webtop.enable {
    environment.systemPackages = with pkgs; [
    # Tiling WM + app suite — terminal-heavy desktop
    sway
    swaybg # wallpaper renderer (sway delegates `output ... bg` to it)
    foot # wayland-native terminal (docks the Zellij session)
    wofi # launcher (SUPER+D)
    firefox
    chromium

    # VNC server + WebSocket proxy + HTML5 client
    wayvnc
    python3Packages.websockify
    novnc
  ];

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
      description = "Headless sway compositor for desktop streaming";
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
        WLR_BACKENDS = "headless";
        WLR_LIBINPUT_NO_DEVICES = "1";
        XDG_RUNTIME_DIR = "/run/user/${toString cfg.uid}";
        WAYLAND_DISPLAY = "wayland-1";
      };
    };

    wayvnc = {
      description = "VNC server for headless desktop";
      wantedBy = [ "default.target" ];
      after = [ "sway-headless.service" ];
      startLimitIntervalSec = 0;
      serviceConfig = {
        Type = "simple";
        # 127.0.0.1: mirrored networking shares the host's interfaces, so
        # 0.0.0.0 would expose the desktop to the LAN. Restart-until-ready
        # covers the race with sway's startup.
        ExecStart = "${pkgs.wayvnc}/bin/wayvnc --output=HEADLESS-1 127.0.0.1 5900";
        Restart = "on-failure";
        RestartSec = 2;
      };
      environment = {
        XDG_RUNTIME_DIR = "/run/user/${toString cfg.uid}";
        WAYLAND_DISPLAY = "wayland-1";
      };
    };

    websockify = {
      description = "WebSocket proxy for noVNC";
      wantedBy = [ "default.target" ];
      after = [ "wayvnc.service" ];
      startLimitIntervalSec = 0;
      serviceConfig = {
        Type = "simple";
        # nixpkgs novnc installs its web root under share/webapps/novnc,
        # not share/novnc; websockify chdirs there at startup.
        ExecStart =
          "${pkgs.python3Packages.websockify}/bin/websockify --web=${pkgs.novnc}/share/webapps/novnc 6080 127.0.0.1:5900";
        Restart = "on-failure";
        RestartSec = 2;
      };
    };
  };
  };
}
