# Docker engine inside the cellar. Off by default — flip
# `cellar.docker.enable = true;` in your flake/override when you need it.
#
# Docker Desktop coexistence:
#   Docker Desktop on Windows and native Docker Engine in the cellar can
#   coexist. The custom BORE kernel in .wslconfig applies globally —
#   including to the hidden docker-desktop WSL distro. The bore.fragment
#   includes CONFIG_ISO9660_FS=y to satisfy Docker Desktop's LinuxKit
#   bootstrap. If Docker Desktop's WSL2 Integration is enabled (Settings
#   → Resources → WSL Integration), it overrides the native Engine inside
#   the cellar. Disable WSL2 Integration to use the native daemon.
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

    users.users."${config.cellar.user}".extraGroups = [ "docker" ];

    environment.systemPackages = [ pkgs.docker-compose ];
  };
}
