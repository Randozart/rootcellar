# RootCellar — the OS definition.
# One flake, one room in the house. Rebuild with:
#   sudo nixos-rebuild switch --flake .#rootcellar
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
            nixpkgs.overlays = [
              (final: prev: {
                opencode = nixpkgs-unstable.legacyPackages.${prev.system}.opencode;
              })
            ];
          }
          ./modules/base.nix
          ./modules/packages.nix
          ./modules/sysctl.nix
          ./modules/deskbottom.nix
          ./modules/docker.nix
          ./modules/gpu.nix
        ];
      };

      devShells.x86_64-linux.kernel = nixpkgs.lib.genAttrs [ "x86_64-linux" ] (
        system:
        nixpkgs.legacyPackages.${system}.mkShell {
          name = "rootcellar-kernel-build";
          packages = with nixpkgs.legacyPackages.${system}; [
            bc
            bison
            cpio
            dwarves
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
        }
      );

      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt-rfc-style;
    };
}
