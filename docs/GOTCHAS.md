# Gotchas

Hard-won issues that do not fit neatly into one module's doc. Symptom-first,
like the rest of the docs. No secrets, no private IPs, no client data
(AGENTS.md rule 3).

## NixOS-WSL kernel & modules

**The running kernel has no loadable modules — build what you need in.**
- The WSL2 utility VM ships no `/lib/modules/<release>` tree for a custom
  kernel. Anything that stock `Microsoft/config-wsl` leaves as `=m` is
  simply unavailable at runtime.
- Symptom: a bare-attached btrfs VHD mounts with `unknown filesystem type
  'btrfs'` even though `btrfs-progs` is installed.
- Fix: put the fs in the kernel fragment as built-in (`CONFIG_BTRFS_FS=y`),
  not a module. See `kernel/bore.fragment`.

**`merge_config.sh` output must land where `make` reads it.**
- `scripts/kconfig/merge_config.sh -m <base> <fragment>` writes the merged
  result to `$KCONFIG_CONFIG`, which defaults to `.config`. If the build
  then runs `make KCONFIG_CONFIG=Microsoft/config-wsl`, the fragment's
  overrides (btrfs=y, LOCALVERSION, HZ) are silently dropped and the build
  uses the stock base. Result: kernel builds "fine" but is missing every
  fragment setting.
- Fix: point `KCONFIG_CONFIG` at the same file for both the merge and the
  `olddefconfig`/`make` steps. See `kernel/build-kernel.sh`.

**`dwarves` is not a nixpkgs 25.05 attribute.**
- The kernel devShell listed `dwarves` (the old package name); evaluation
  fails with `undefined variable 'dwarves'`. The package is `pahole` in
  25.05. Fix in `flake.nix`.

## VITRIOL build (CUDA)

**FindCUDAToolkit wants `lib64` and the shared `libcudart.so`.**
- nixpkgs 25.05 splits CUDA packages into `lib`/`dev`/`static` outputs, and
  `symlinkJoin` ignores `postBuild` (so a `lib64` symlink is never created).
- Symptom: cmake fails `Could NOT find CUDAToolkit (missing: CUDA_CUDART)`
  even though the toolkit is on the store. Two separate causes, both fixed
  in `flake.nix`:
  1. Join `cuda_cudart.lib` explicitly — the bare `cuda_cudart` attr only
     carries the default output, which lacks the shared `.so`.
  2. Bridge `lib64 → lib` inside the joined toolkit so FindCUDAToolkit
     finds the lib dir. (`symlinkJoin` won't do it via `postBuild`.)
- The `devShells.vitriol` `env` block must carry `CUDAToolkit_ROOT`,
  `CUDACXX`, and `LD_LIBRARY_PATH`, because `nix develop -c` skips
  `shellHook` — the exports are inert otherwise.

**llama-server flag names drift between engines.**
- The main-tree `llama-server` renamed `--checkpoint-every-n-tokens` to
  `--checkpoint-min-step`, and speculative types from `mtp` to `draft-mtp`.
  The `vitriol` launcher (in the VITRIOL repo) must match the binary it is
  built against; check `--help` before assuming a flag name.

## Hardware / build target

- Build arch for the RTX 4000 SFF Ada is `sm_89`. The VITRIOL build script
  defaults to the older dual-GPU box's `61;86` — override with
  `CUDA_ARCHITECTURES=89` (or patch the script).
- The card's ~306 GB/s memory bandwidth is the throughput ceiling for a
  27B dense model (~23 tok/s generation); no config change makes it faster,
  only smaller models or smaller quants do.