# The Deskbottom Environment: fish + Raddix prompt, Zellij as WM,
# `cellar` as start menu, and the MOTD that greets you in the cellar.
# Visual identity: docs/BRANDING.md.
{
  pkgs,
  ...
}:

let
  cellarApp = pkgs.writeShellScriptBin "cellar" (builtins.readFile ../deskbottom/bin/cellar);

  cellarConfigs = pkgs.runCommand "cellar-configs" { } ''
    mkdir -p $out/zellij/layouts
    cp ${../deskbottom/zellij/config.kdl}         $out/zellij/config.kdl
    cp ${../deskbottom/zellij/layouts/cellar.kdl} $out/zellij/layouts/cellar.kdl
    cp ${../deskbottom/apps.toml}                 $out/apps.toml
    cp ${../deskbottom/shell/fish_prompt.fish}    $out/fish_prompt.fish
    cp ${../deskbottom/fastfetch/raddix.ans}      $out/raddix.ans
    cp ${../deskbottom/fastfetch/config.jsonc}    $out/fastfetch-config.jsonc
  '';
in
{
  environment.systemPackages = [ cellarApp ];

  environment.etc."cellar".source = cellarConfigs;
  environment.etc."xdg/fastfetch/config.jsonc".source = "${cellarConfigs}/fastfetch-config.jsonc";

  environment.variables = {
    ZELLIJ_CONFIG_DIR = "/etc/cellar/zellij";
    CELLAR_APPS = "/etc/cellar/apps.toml";
  };

  users.motd = ''
    Welcome to the cellar.

        ⌒ ⋎ ⌒
      ⌒ ⌒   ⌒ ⌒
       .──────.
      (  '.'  )
       '──────'
         ╲╱
         ⌣
    Raddix · RootCellar OS
  '';

  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      set -gx CELLAR_HOME "$HOME/.local/share/cellar"
      mkdir -p $CELLAR_HOME
      source /etc/cellar/fish_prompt.fish
      # Auto-boot the deskbottom on interactive login.
      # Opt out per-session with: set -gx CELLAR_NO_AUTOSTART 1
      if test -z "$ZELLIJ"; and test -z "$CELLAR_NO_AUTOSTART"; and test "$TERM" != "dumb"; and test -t 0
          exec ${cellarApp}/bin/cellar deskbottom
      end
    '';
  };

  # zsh stays installed as a fallback shell; fish is the house shell.
}
