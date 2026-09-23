# RootCellar — the OS definition.
# One flake, one room in the house. Rebuild with:
#   sudo nixos-rebuild switch --flake .#rootcellar
#
# Input hygiene: the pins below are committed in flake.lock and are
# what cache.nixos.org has already built. Moving an input (nix flake
# update) re-hashes labwc, wlroots, opencode and every package built
# against that pin and forces source rebuilds — only bump when a real
# upgrade is wanted, never out of habit.
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";

    # One-package exception: the pinned 25.05 carries opencode 0.3.x, which
    # cannot read the 1.x session database. Only opencode comes from here;
    # the system base stays on the stable pin above.
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-unstable,
      nixos-wsl,
      ...
    }:
    {
      nixosConfigurations.rootcellar = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          nixos-wsl.nixosModules.default
          {
            # Change me. Identity of your cellar; everything else in the
            # modules references these. Leaving `user` unset fails the
            # eval loudly instead of booting with a surprise user.
            cellar.user = "randy";
            cellar.uid = 1000;

            nixpkgs.overlays = [
              (final: prev: {
                opencode = nixpkgs-unstable.legacyPackages.${prev.system}.opencode;
                cellar-software-center = final.callPackage ./pkgs/cellar-software-center { };
                rootcellar-control-center = final.callPackage ./pkgs/rootcellar-control-center { };
              })
            ];
          }
          ./modules/base.nix
          ./modules/settings.nix
          ./modules/packages.nix
          ./modules/sysctl.nix
          ./modules/deskbottom.nix
          ./modules/docker.nix
          ./modules/devtools.nix
          ./modules/webtop.nix
          ./modules/plasma.nix
          ./modules/gpu.nix
        ];
      };

      devShells.x86_64-linux.kernel = nixpkgs.legacyPackages.x86_64-linux.mkShell {
        name = "rootcellar-kernel-build";
        packages = with nixpkgs.legacyPackages.x86_64-linux; [
          bc
          bison
          cpio
          pahole
          elfutils
          flex
          gcc
          git
          ncurses
          openssl
          pkg-config
          python3
          rsync
          zlib
        ];
      };

      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt-rfc-style;
    };
}
