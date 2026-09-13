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
            # Change me. Identity of your cellar; everything else in the
            # modules references these. Leaving `user` unset fails the
            # eval loudly instead of booting with a surprise user.
            cellar.user = "randy";
            cellar.uid = 1000;

            nixpkgs.overlays = [
              (final: prev: {
                opencode = nixpkgs-unstable.legacyPackages.${prev.system}.opencode;
                carbonyl = final.callPackage ./pkgs/carbonyl.nix { };
                waymote = final.callPackage ./pkgs/waymote.nix { };

                # wlroots 0.18.3 (still present in 0.20.x) aborts the
                # compositor when one pointer frame carries axis events
                # with different sources: waymote's virtual-pointer scroll
                # stamps axis_source on the previous axis, so a two-axis
                # scroll (laptop touchpads: dx AND dy nonzero) sends one
                # continuous and one wheel-sourced event — assertion, sway
                # SIGABRT. Re-emit axis_source on mismatch instead, and
                # reset the frame flag even with no focused client. See
                # PLAN-HYPRDESK.md, Phase 4. sway builds against the
                # versioned wlroots_0_18 attr, not the `wlroots` alias.
                wlroots_0_18 = prev.wlroots_0_18.overrideAttrs (old: {
                  patches = (old.patches or [ ]) ++ [ ./pkgs/wlroots-axis-source.patch ];
                });
              })
            ];
          }
          ./modules/base.nix
          ./modules/settings.nix
          ./modules/packages.nix
          ./modules/sysctl.nix
          ./modules/deskbottom.nix
          ./modules/docker.nix
          ./modules/webtop.nix
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
