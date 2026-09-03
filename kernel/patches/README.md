# Vendored BORE Patches

This directory holds the BORE scheduler patch **actually built into the
RootCellar kernel**. It is committed to the repo so every rebuild is
reproducible without network access.

## Layout

- `bore-6.6-cachy.patch` — the CachyOS-flavored BORE patch for the 6.6
  kernel series (source: CachyOS/kernel-patches).

## State

`../PATCH_VERSION` records the source, sha256, and date of the vendored
patch. The sha256 must match the patch file — CI enforces drift.

## Updating (CachyOS-style patch listening)

```sh
kernel/check-upstream.sh              # report drift vs upstream
kernel/check-upstream.sh --download   # update patch + PATCH_VERSION atomically
kernel/build-kernel.sh                # rebuild and reinstall the kernel
```

A scheduled GitHub Action (`.github/workflows/patch-watch.yml`) runs the
check periodically once this repo is pushed.

## Rules (see also AGENTS.md)

- Never hand-edit a vendored patch without updating `PATCH_VERSION` in the
  same commit.
- Never bump the kernel series (e.g. 6.6 → 6.18) without updating
  `PATCH_VERSION`'s `kernel_series`, re-vendoring the matching patch, and
  verifying `build-kernel.sh` end to end.
