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
    mkdir -p $out/labwc
    cp ${../deskbottom/zellij/config.kdl}         $out/zellij/config.kdl
    cp ${../deskbottom/zellij/layouts/cellar.kdl} $out/zellij/layouts/cellar.kdl
    cp ${../deskbottom/zellij/layouts/main.kdl}   $out/zellij/layouts/main.kdl
    cp ${../deskbottom/cheatsheet.txt}            $out/cheatsheet.txt
    cp ${../deskbottom/apps.toml}                 $out/apps.toml
    cp ${../deskbottom/shell/fish_prompt.fish}    $out/fish_prompt.fish
    cp ${../deskbottom/fastfetch/config.jsonc}    $out/fastfetch-config.jsonc
    cp ${../deskbottom/labwc/autostart}           $out/labwc/autostart
    cp ${../assets/rootcellar-ascii.ans}          $out/wordmark.ans
    {
      echo ""
      cat $out/wordmark.ans
      echo ""
      echo "  Welcome to the cellar."
      echo ""
      echo "  cellar              boot the deskbottom"
      echo "  cellar app          pick an app from the start menu"
      echo "  cellar list         see what is installed"
      echo "  cellar update       pull updates and rebuild"
      echo "  cellar --help       full command reference"
      echo ""
      echo "  Hint: type help for info on how to use the terminal."
      echo ""
    } > $out/motd
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

  # MOTD: wordmark + welcome + Raddix (ANSI-colored), composed in cellarConfigs.
  environment.etc."motd".source = "${cellarConfigs}/motd";

  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      # Replace the default version banner with the cellar MOTD.
      set -g fish_greeting ""
      function fish_greeting
          if test -t 1
              cat /etc/motd
          end
      end

      set -gx CELLAR_HOME "$HOME/.local/share/cellar"
      mkdir -p $CELLAR_HOME
      # Cellar LS_COLORS. The coreutils default database paints dirs with
      # solid backgrounds (world-writable = green bg, sticky = black bg),
      # which drowns filenames on any highlight. This spec is
      # foreground-only and maps onto the WezTerm ANSI palette:
      # 34=dblue 36=teal 35=purple 31=rose 32=sea 33=sand.
      # All dir classes (di/ow/st/tw) share bold blue: one meaning, no bg.
      set -gx LS_COLORS "di=01;34:ln=01;36:or=01;31:ex=01;32:so=01;35:do=01;35:pi=33:bd=01;33:cd=01;33:su=01;33:sg=01;33:ca=01;31:mi=00:*.tar=01;31:*.tgz=01;31:*.gz=01;31:*.xz=01;31:*.zst=01;31:*.zip=01;31:*.7z=01;31:*.rar=01;31:*.bz2=01;31:*.deb=01;31:*.rpm=01;31:*.jar=01;31:*.iso=01;31:*.jpg=01;35:*.jpeg=01;35:*.png=01;35:*.gif=01;35:*.webp=01;35:*.svg=01;35:*.mp4=01;35:*.mkv=01;35:*.webm=01;35:*.avi=01;35:*.mov=01;35:*.mp3=00;36:*.flac=00;36:*.ogg=00;36:*.wav=00;36"
      source /etc/cellar/fish_prompt.fish
      ${pkgs.atuin}/bin/atuin init fish | source
      # Auto-boot the deskbottom on interactive login.
      # Opt out per-session with: set -gx CELLAR_NO_AUTOSTART 1
      if test -z "$ZELLIJ"; and test -z "$CELLAR_NO_AUTOSTART"; and test "$TERM" != "dumb"; and test -t 0
          exec ${cellarApp}/bin/cellar deskbottom
      end
    '';
  };

  # zsh stays installed as a fallback shell; fish is the house shell.
}
