# The tool chest. Everything the deskbottom expects to find on PATH.
{ pkgs, ... }:

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
  ];
}
