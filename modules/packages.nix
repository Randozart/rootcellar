# The tool chest. Everything the deskbottom expects to find on PATH,
# plus the cozy layer: modules/user-packages.list (managed by
# `cellar add` / `cellar remove`).
{ lib, pkgs, ... }:

let
  # One attribute path per line; '#' comments and blank lines ignored.
  # A path that does not resolve fails the eval loudly — `cellar add`
  # validates before writing, so this only fires on hand edits.
  userEntries =
    lib.filter (l: l != "" && !(lib.hasPrefix "#" l))
      (lib.splitString "\n" (builtins.readFile ./user-packages.list));

  resolve = p:
    if lib.hasAttrByPath (lib.splitString "." p) pkgs
    then lib.getAttrFromPath (lib.splitString "." p) pkgs
    else throw "modules/user-packages.list: '${p}' not found in nixpkgs — run 'cellar check ${p}'";
in

{
  environment.systemPackages = with pkgs; [
    # Multiplexer + deskbottom apps
    zellij
    yazi
    broot
    btop
    lazygit
    lazydocker

    # Editor + shell quality of life
    neovim
    helix
    fish
    zsh
    fzf
    zoxide
    direnv
    atuin

    # Modern coreutils-adjacent
    ripgrep
    bat
    fd
    eza
    jq
    yq

    # Media + graphics (kitty protocol rendering)
    chafa
    timg
    mpv
    ffmpeg

    # System + network basics
    git
    curl
    wget
    less
    fastfetch
    htop
    tmux
    file
    which
    tree
    unzip
    zip
    p7zip
    btrfs-progs

    # Development
    gh
    shellcheck
    hyperfine

    # AI pair programmer + its database inspection
    opencode
    sqlite

    # Web (terminal)
    carbonyl
  ] ++ map resolve userEntries;
}
