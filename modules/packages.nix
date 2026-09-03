# The tool chest. Everything the deskbottom expects to find on PATH.
{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # Multiplexer + desktop apps
    zellij
    yazi
    btop
    lazygit
    lazydocker

    # Editor + shell quality of life
    neovim
    helix
    starship
    zsh
    fzf
    zoxide
    direnv

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
  ];
}
