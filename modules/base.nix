# Base identity of the cellar: user, hostname, locale, Nix itself.
{ config, lib, pkgs, ... }:

let
  cfg = config.cellar;
in

{
  options.cellar = {
    # Set these in flake.nix (the "change me" block). No default on
    # purpose: an unset identity fails the eval loudly instead of
    # booting a machine with a surprise user.
    user = lib.mkOption {
      type = lib.types.str;
      description = "Primary user of the cellar (also the WSL default user).";
    };

    uid = lib.mkOption {
      type = lib.types.int;
      default = 1000;
      description = "UID of the primary user. 1000 is the WSL convention.";
    };
  };

  config = {
    wsl.enable = true;
    wsl.defaultUser = cfg.user;
    wsl.wslConf.interop.appendWindowsPath = false;
    # WSL registers the WSLInterop binfmt handler (MZ -> /init) at distro
    # boot, but nothing guarantees it survives: a fresh binfmt_misc mount,
    # a reconfig, or activity in a sibling distro can drop it. Once gone,
    # no Windows .exe runs from the cellar — windowctl, powershell, cmd —
    # and the waybar window controls silently die. Register it
    # declaratively so systemd-binfmt re-adds it at every boot
    # (wsl.interop.register -> boot.binfmt.registrations.WSLInterop).
    # binfmt_misc is per mount namespace, so this touches only the cellar.
    wsl.interop.register = true;
    # WSL's generated resolv.conf points at the mirrored-mode DNS proxy,
    # which the corporate network chokes on. Stop WSL from writing it and
    # generate our own from the live default gateway at boot instead (the
    # NAT subnet changes across wsl --shutdown, so it cannot be hardcoded).
    wsl.wslConf.network.generateResolvConf = false;
    # resolvconf rewrites /etc/resolv.conf with no usable nameservers in
    # the WSL environment; the cellar-resolv service below owns the file.
    networking.resolvconf.enable = false;

    # Default only — cellar.toml (modules/settings.nix) overrides this.
    networking.hostName = lib.mkDefault "cellar";

    # DNS resolver: refreshed by a timer every 60s so the cellar survives
    # Wi-Fi switches, sleep/resume, and VPN toggles without wsl --shutdown.
    # Tries the WSL DNS proxy first (honors VPN NRPT when dnsTunneling=true),
    # then falls back to the live gateway and public resolvers.
    systemd.services.cellar-resolv = {
      description = "Write resolv.conf from the live default gateway";
      serviceConfig = {
        Type = "oneshot";
        # A writeShellScript file, not an inline ExecStart string: nested
        # nix -> systemd -> bash quoting mangles escapes like \$3 and the
        # gateway quietly degrades (see resolv.conf drift on 2026-09-11).
        ExecStart = pkgs.writeShellScript "cellar-resolv" ''
          GW=$(${pkgs.iproute2}/bin/ip route show default | ${pkgs.gawk}/bin/awk '{print $3; exit}')
          if [[ -n "$GW" ]]; then
            ${pkgs.coreutils}/bin/printf \
              "nameserver 10.255.255.254\nnameserver %s\nnameserver 1.1.1.1\nnameserver 8.8.8.8\n" \
              "$GW" > /etc/resolv.conf
          else
            echo "cellar-resolv: no default route, skipping" >&2
          fi
        '';
      };
    };

    systemd.timers.cellar-resolv = {
      description = "Refresh resolv.conf periodically and on boot";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = 0;
        OnUnitActiveSec = 60;
        Persistent = true;
      };
    };

    users.users."${cfg.user}" = {
      isNormalUser = true;
      uid = cfg.uid;
      home = "/home/${cfg.user}";
      extraGroups = [ "wheel" ];
      shell = pkgs.fish;
    };

    # Defaults only — cellar.toml (modules/settings.nix) overrides these.
    time.timeZone = lib.mkDefault "Europe/Amsterdam";
    i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";

    # Chromium-family binaries CHECK-crash silently on font init
    # with a degenerate font set — NixOS-WSL ships no fonts unless declared.
    fonts = {
      fontconfig.enable = true;
      packages = with pkgs; [
        inter # UI font — purpose-built for screens, clean at 11-13px
        noto-fonts
        noto-fonts-emoji
        nerd-fonts.symbols-only # waybar icons (menu, window controls, etc.)
        jetbrains-mono # first in the WezTerm fallback list
        dejavu_fonts # ultimate fallback (many apps hardcode it)
      ];
    };

    nix.settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      # Hard-link identical files across store paths: dedupes the many
      # near-identical closures a desktop system pulls in, so rebuilds
      # and downloads do less work.
      auto-optimise-store = true;
    };
    nixpkgs.config.allowUnfree = true;

    # Collect old generations weekly but never the current system closure,
    # so sway/firefox/the toolchain stay cached between deploys instead of
    # being evicted and rebuilt. --max-freed caps how much a run reclaims.
    nix.gc = {
      automatic = true;
      dates = "Mon 03:00";
      options = "--max-freed 5G";
    };

    security.sudo.wheelNeedsPassword = true;

    # Without this, WSL tears the distro down ~60s after the last terminal
    # closes and every zellij session dies with it. A single idle process
    # keeps the cellar resident, matching how Fedora behaves (its distro is
    # held up by long-running tooling). Costs a few hundred MB idle.
    systemd.services.cellar-keepalive = {
      description = "Keep the cellar distro resident";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.coreutils}/bin/sleep infinity";
        Restart = "on-failure";
      };
    };

    # systemd is PID 1 by default in NixOS-WSL >= 1.5; do not disable.

    system.stateVersion = "25.05";
  };
}
