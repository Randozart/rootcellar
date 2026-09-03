# Docker engine inside the cellar. Off by default — flip
# `cellar.docker.enable = true;` in your flake/override when you need it.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cellar.docker;
in
{
  options.cellar.docker.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Enable the Docker daemon (requires systemd, which NixOS-WSL provides).";
  };

  config = lib.mkIf cfg.enable {
    virtualisation.docker = {
      enable = true;
      enableOnBoot = true;
    };

    users.users.randy.extraGroups = [ "docker" ];

    environment.systemPackages = [ pkgs.docker-compose ];
  };
}
