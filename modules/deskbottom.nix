# The Deskbottom Environment: Zellij as WM, `cellar` as start menu,
# shell integration, and the MOTD that greets you in the cellar.
{
  pkgs,
  ...
}:

let
  cellarApp = pkgs.writeShellScriptBin "cellar" (builtins.readFile ../deskbottom/bin/cellar);

  cellarConfigs = pkgs.runCommand "cellar-configs" { } ''
    mkdir -p $out/zellij/layouts
    cp ${../deskbottom/zellij/config.kdl}        $out/zellij/config.kdl
    cp ${../deskbottom/zellij/layouts/cellar.kdl} $out/zellij/layouts/cellar.kdl
    cp ${../deskbottom/apps.toml}                 $out/apps.toml
  '';
in
{
  environment.systemPackages = [ cellarApp ];

  environment.etc."cellar".source = cellarConfigs;

  environment.variables = {
    ZELLIJ_CONFIG_DIR = "/etc/cellar/zellij";
    CELLAR_APPS = "/etc/cellar/apps.toml";
  };

  users.motd = "Welcome to the cellar.";

  programs.zsh = {
    enable = true;
    autosuggestions.enable = true;
    syntaxHighlighting.enable = true;

    shellInit = ''
      export CELLAR_HOME="$HOME/.local/share/cellar"
      mkdir -p "$CELLAR_HOME"
    '';

    # Auto-boot the desktop on interactive login.
    # Opt out per-session with: export CELLAR_NO_AUTOSTART=1
    interactiveShellInit = ''
      if [[ -z "''${ZELLIJ:-}" \
            && -z "''${CELLAR_NO_AUTOSTART:-}" \
            && "$TERM" != "dumb" \
            && -t 0 ]]; then
        exec ${cellarApp}/bin/cellar desktop
      fi
    '';
  };

  programs.starship = {
    enable = true;
    settings = {
      add_newline = false;
      hostname = {
        ssh_only = false;
        format = "[$hostname](bold dimmed green) in ";
      };
    };
  };
}
