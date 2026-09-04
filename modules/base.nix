# Base identity of the cellar: user, hostname, locale, Nix itself.
{ config, pkgs, ... }:

{
  wsl.enable = true;
  wsl.defaultUser = "randy";
  wsl.wslConf.interop.appendWindowsPath = false;
  # WSL's generated resolv.conf points at the mirrored-mode DNS proxy, which
  # the corporate network chokes on. Stop WSL from writing it and generate
  # our own from the live default gateway at boot instead (the NAT subnet
  # changes across wsl --shutdown, so the gateway cannot be hardcoded).
  wsl.wslConf.network.generateResolvConf = false;
  # resolvconf rewrites /etc/resolv.conf with no usable nameservers in the
  # WSL environment; the cellar-resolv service below owns the file instead.
  networking.resolvconf.enable = false;

  networking.hostName = "cellar";

  systemd.services.cellar-resolv = {
    description = "Write resolv.conf from the live default gateway";
    wantedBy = [ "multi-user.target" ];
    before = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      GW=$(${pkgs.iproute2}/bin/ip route show default | ${pkgs.gawk}/bin/awk '{print $3; exit}')
      ${pkgs.coreutils}/bin/printf 'nameserver %s\nnameserver 1.1.1.1\nnameserver 8.8.8.8\n' "$GW" > /etc/resolv.conf
    '';
  };

  users.users.randy = {
    isNormalUser = true;
    uid = 1000;
    home = "/home/randy";
    extraGroups = [ "wheel" ];
    shell = pkgs.fish;
  };

  time.timeZone = "Europe/Amsterdam"; # adjust to your timezone
  i18n.defaultLocale = "en_US.UTF-8";

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nixpkgs.config.allowUnfree = true;

  security.sudo.wheelNeedsPassword = true;

  # systemd-binfmt.service flushes the VM-wide binfmt table when it starts,
  # which kills WSLInterop for every other distro in the utility VM
  # (upstream WSL bug; see docs/TROUBLESHOOTING.md). The cellar does not
  # use binfmt emulation, so the unit is disabled declaratively.
  systemd.units."systemd-binfmt.service".enable = false;

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
}
