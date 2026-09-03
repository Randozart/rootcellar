# Base identity of the cellar: user, hostname, locale, Nix itself.
{ config, pkgs, ... }:

{
  wsl.enable = true;
  wsl.defaultUser = "randy";
  wsl.interop.appendWindowsPath = false;

  networking.hostName = "cellar";

  users.users.randy = {
    isNormalUser = true;
    uid = 1000;
    home = "/home/randy";
    extraGroups = [ "wheel" ];
    shell = pkgs.zsh;
  };

  time.timeZone = "Europe/Amsterdam"; # adjust to your timezone
  i18n.defaultLocale = "en_US.UTF-8";

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nixpkgs.config.allowUnfree = true;

  security.sudo.wheelNeedsPassword = true;

  # systemd is PID 1 by default in NixOS-WSL >= 1.5; do not disable.

  system.stateVersion = "25.05";
}
