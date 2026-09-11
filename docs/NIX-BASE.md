# NixOS Base & Bootstrap

RootCellar is a NixOS-WSL configuration. The flake *is* the OS: everything —
user, packages, Zellij, sysctls, the deskbottom — is declared in `flake.nix` and
`modules/`. If a rebuild misbehaves, you boot the previous generation. That
is the resilience story: mistakes are reversible by construction.

## Prerequisites

- Windows 11 (22H2+ recommended for mirrored networking)
- WSL 2.4.4+ (`wsl --update`)
- The RootCellar kernel installed via `kernel/build-kernel.sh` and set in
  `.wslconfig` (see `docs/BORE-SCHEDULER.md`)

## Bootstrap, first time

1. Download `nixos.wsl` from
   [NixOS-WSL releases](https://github.com/nix-community/NixOS-WSL/releases/latest)
   and double-click it (or `wsl --install --from-file nixos.wsl`).

2. Enter it:

   ```powershell
   wsl -d NixOS
   ```

3. Fetch the cellar definition and switch into it:

   ```bash
   sudo nixos-rebuild switch --flake github:<you>/rootcellar#rootcellar
   # or, from a checkout:
   git clone <your-fork-url> /rootcellar
   cd /rootcellar && sudo nixos-rebuild switch --flake .#rootcellar
   ```

4. Restart your WSL session. The login banner should read
   **Welcome to the cellar.** and your prompt should be `<you>@cellar`.

## Everyday operation

```bash
# After editing modules/ or deskbottom/:
sudo nixos-rebuild switch --flake .#rootcellar

# Inspect generations:
nix-env --list-generations --profile /nix/var/nix/profiles/system

# Roll back to the previous generation (immediate, no rebuild):
sudo /nix/var/nix/profiles/system/bin/switch-to-configuration switch
# Or boot the previous generation: hold it in the WSL boot via
# `nixos-rebuild switch --rollback` equivalent:
sudo nix-env --profile /nix/var/nix/profiles/system --rollback
sudo /nix/var/nix/profiles/system/bin/switch-to-configuration switch
```

## Module map

| Module | Concern | Toggle |
|--------|---------|--------|
| `base.nix` | user from `cellar.user` (uid 1000, fish shell), hostname `cellar`, locale, flakes | edit directly |
| `packages.nix` | the tool chest | edit directly |
| `sysctl.nix` | inotify limits (applied by systemd-sysctl) | edit directly |
| `deskbottom.nix` | fish + Raddix prompt, Zellij config install, `cellar` CLI, autostart, MOTD | `CELLAR_NO_AUTOSTART=1` per session |
| `docker.nix` | Docker daemon | `cellar.docker.enable = true;` |
| `gpu.nix` | CUDA toolkit + lib path ordering | `cellar.cuda.enable = true;` |

## Non-Nix users

The kernel pipeline (`kernel/`) and Windows scripts (`windows/`) are
distro-agnostic. An Arch or Fedora WSL distro works fine with those parts —
you just lose atomic rollbacks and the declarative deskbottom. The flake is the
recommended path, not the only one.
