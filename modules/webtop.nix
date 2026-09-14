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

  # streamd hardcodes `pkt_size=60000` into its ffmpeg invocation. WSL2
  # mirrored networking relays loopback UDP through a path that silently
  # drops any datagram above 1472 bytes (Ethernet MTU payload), so every
  # keyframe-sized RTP packet died in transit and the browser sat at
  # "Waiting for the first keyframe" forever. Rewrite the size to 1400:
  # keyframes arrive as standard FU-A fragments, which the gateway's
  # assembler reassembles natively. See PLAN-HYPRDESK.md, Phase 4.
  #
  # Two more surgical rewrites for stall recovery at 60fps (Phase 5d):
  # - `-g 60`/`-keyint_min 60` → 30: keyframes twice a second, so a
  #   packet-loss or queue-overflow stall resyncs in <=0.5s instead of
  #   a full second-plus — the "occasionally hangs" pattern.
  # - drop `-re`: it paces input reads at exactly 60fps, so when the
  #   capture side stalls and then bursts, ffmpeg re-drains the backlog
  #   at 1x realtime — freezing the present to replay the past. Without
  #   it, a stall drains instantly; healthy capture rate is unchanged.
  ffmpeg-rtp = pkgs.writeShellScriptBin "ffmpeg" ''
    set -Eeuo pipefail
    args=()
    prev=""
    for a in "$@"; do
      case "$prev" in
        -g | -keyint_min) a="30" ;;
      esac
      if [[ "$a" == "-re" ]]; then
        prev=""
        continue
      fi
      a="''${a//pkt_size=60000/pkt_size=1400}"
      args+=("$a")
      prev="$a"
    done
    exec "${pkgs.ffmpeg}/bin/ffmpeg" "''${args[@]}"
  '';

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
            SWAYSOCK="$sock" swaymsg exec "foot -e zellij attach cellar --create" >/dev/null 2>&1 || true
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
    swaybg # wallpaper renderer (sway delegates `output ... bg` to it)
    waybar # top panel: workspaces, clock, window title, tray
    foot # wayland-native terminal (docks the Zellij session)
    wofi # launcher (SUPER+D)
    wl-clipboard # Ctrl+C/V between kiosk and terminal
    firefox
    chromium

    # VNC server + WebSocket proxy + HTML5 client
    wayvnc
    python3Packages.websockify
    novnc

    # H.264 browser streaming (overlay tier); ffmpeg supplies libx264
    waymote
    ffmpeg
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

    # Headless VNC/websockify/waymote services: disabled — the native
    # WSLg path replaces the browser-kiosk pipeline. Kept in the module
    # for reference and manual re-enablement if needed.
    wayvnc = {
      description = "VNC server for headless desktop";
      # wantedBy disabled: HEADLESS-1 output gone; WSLg nesting replaces browser streaming
      # wantedBy = [ "default.target" ];
      after = [ "sway-headless.service" ];
      startLimitIntervalSec = 0;
      serviceConfig = {
        Type = "simple";
        # 127.0.0.1: mirrored networking shares the host's interfaces, so
        # 0.0.0.0 would expose the desktop to the LAN. Restart-until-ready
        # covers the race with sway's startup.
        ExecStart = "${pkgs.wayvnc}/bin/wayvnc --output=HEADLESS-1 127.0.0.1 5900";
        # wayvnc exits 0 when its Wayland connection drops (sway bounce),
        # which on-failure treats as success and leaves us locked out.
        Restart = "always";
        RestartSec = 2;
      };
      environment = {
        XDG_RUNTIME_DIR = "/run/user/${toString cfg.uid}";
        WAYLAND_DISPLAY = "wayland-1";
      };
    };

    websockify = {
      description = "WebSocket proxy for noVNC";
      # wantedBy disabled: depends on wayvnc which targets HEADLESS-1
      # wantedBy = [ "default.target" ];
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

    waymote-gateway = {
      description = "Waymote gateway: H.264 browser stream for the headless desktop";
      # wantedBy disabled: HEADLESS-1 output gone; WSLg nesting replaces browser streaming
      # wantedBy = [ "default.target" ];
      after = [ "sway-headless.service" ];
      startLimitIntervalSec = 0;
      serviceConfig = {
        Type = "simple";
        # Same mirrored-networking rule as wayvnc: 127.0.0.1 only, since
        # waymote has no authentication — a wider bind would hand input
        # and clipboard control to the LAN. The fixed 1920x1200 output is
        # the panel's physical pixel count: streamd resizes HEADLESS-1
        # through zwlr_output_manager so the stream carries native
        # pixels instead of the browser upscaling a logical-size frame
        # by the Windows DPI factor.
        ExecStart = ''
          ${pkgs.waymote}/bin/waymote-gateway \
            -listen 127.0.0.1:8090 \
            -public-url http://localhost:8090 \
            -streamd ${pkgs.waymote}/bin/waymote-streamd \
            -fixed-width 1920 -fixed-height 1200 \
            -frame-rate 60
        '';
        # When streamd loses Wayland (sway bounce) the gateway shuts down
        # cleanly (exit 0) — on-failure would treat that as done and stay
        # dead. always keeps the stream endpoint self-healing.
        Restart = "always";
        RestartSec = 2;
        # The encoder stack (gateway -> streamd -> ffmpeg, all inheriting
        # this) yields to everything interactive: under load spikes — nix
        # builds, git on drvfs — the stream degrades softly instead of
        # starving the desktop into multi-second freezes.
        Nice = 10;
        CPUSchedulingPolicy = "idle";
      };
      environment = {
        XDG_RUNTIME_DIR = "/run/user/${toString cfg.uid}";
        WAYLAND_DISPLAY = "wayland-1";
        # streamd execs `ffmpeg` for the x264 encode: the wrapper shadows
        # the real binary to keep RTP datagrams under the mirrored-
        # loopback MTU (see ffmpeg-rtp above). The wrapper MUST precede
        # /run/current-system/sw/bin: the system profile also carries a
        # real ffmpeg (environment.systemPackages above), and PATH order
        # decides which one streamd resolves — the 17:23 generation had
        # the wrapper second and it silently lost. The module system
        # already defines a unit-level PATH (hence mkForce, mirroring
        # the sway unit above).
        PATH = lib.mkForce "${ffmpeg-rtp}/bin:/run/current-system/sw/bin:${pkgs.ffmpeg}/bin";
      };
    };
  };
  };
}
