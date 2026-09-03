# Base identity of the cellar: user, hostname, locale, Nix itself.
{ config, pkgs, ... }:

{
  wsl.enable = true;
  wsl.defaultUser = "randy";
  wsl.wslConf.interop.appendWindowsPath = false;

  networking.hostName = "cellar";

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

  # systemd is PID 1 by default in NixOS-WSL >= 1.5; do not disable.

  system.stateVersion = "25.05";
}
