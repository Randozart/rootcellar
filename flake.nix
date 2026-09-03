# RootCellar — the OS definition.
# One flake, one room in the house. Rebuild with:
#   sudo nixos-rebuild switch --flake .#rootcellar
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";

    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self, nixpkgs, nixos-wsl, ... }:
    {
      nixosConfigurations.rootcellar = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          nixos-wsl.nixosModules.default
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
