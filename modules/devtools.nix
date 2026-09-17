# Prepackaged development tools — the "common tools" that ship with the
# base so a fresh cellar can start developing immediately. Opt out on a
# lean machine with `cellar.devtools.enable = false` in an override.
# Docker lives in modules/docker.nix (toggled via cellar.toml [docker]).
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cellar.devtools;
in
{
  options.cellar.devtools.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Install the base development toolset (editor, runtimes, build tools).";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      vscodium # open-source build of VS Code
      nodejs # JavaScript runtime
      python3 # Python interpreter
      go # Go toolchain
      gcc # C/C++ compiler
      gnumake # make
      cmake # cross-platform build system
      direnv # per-directory environment loader
      just # command runner
    ];
  };
}