# Cozy settings bridge: cellar.toml -> NixOS options.
# builtins.fromTOML over a repo file — no IFD, no fetch. A missing file
# or key falls through to the module defaults (base.nix uses mkDefault),
# so deleting cellar.toml is always safe.
{ lib, ... }:

let
  tomlPath = ../cellar.toml;
  settings =
    if builtins.pathExists tomlPath
    then builtins.fromTOML (builtins.readFile tomlPath)
    else { };
in

{
  networking.hostName = lib.mkOverride 990 (lib.attrByPath [ "hostname" ] "cellar" settings);
  time.timeZone = lib.mkOverride 990 (lib.attrByPath [ "timezone" ] "Europe/Amsterdam" settings);
  i18n.defaultLocale = lib.mkOverride 990 (lib.attrByPath [ "locale" ] "en_US.UTF-8" settings);

  cellar.docker.enable = lib.attrByPath [ "docker" "enable" ] false settings;
  cellar.cuda.enable = lib.attrByPath [ "cuda" "enable" ] false settings;
  cellar.cuda.version = lib.attrByPath [ "cuda" "version" ] "" settings;
  cellar.webtop.enable = lib.attrByPath [ "webtop" "enable" ] true settings;
}
