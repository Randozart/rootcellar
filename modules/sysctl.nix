# Kernel knobs that matter inside the cellar.
# NixOS-WSL boots with systemd as PID 1, so systemd-sysctl applies these
# at boot — no wsl.conf [boot] command hack required.
{ ... }:

{
  boot.kernel.sysctl = {
    # File watching for monorepos / dev servers / editors.
    # Default 8192 is a fossil; each watch costs ~1KB kernel memory worst case.
    "fs.inotify.max_user_watches" = 524288;
    "fs.inotify.max_user_instances" = 1024;

    # BORE: pin max-interactivity desktop presets (docs/BORE-SCHEDULER.md).
    # Compiled defaults are 1536; the cellar prefers snappy interactive
    # response over build throughput (user choice 2026-09-23).
    # A/B 2026-09-23: Desktop engine-start stall was NOT caused by
    # sched_bore (still stuck at =0) — keep the master switch on.
    # offset/smoothness/inherit/cache stay at CachyOS defaults — pin only
    # what we intentionally change, so a future patch default bump shows
    # up as a deliberate diff.
    "kernel.sched_bore" = 1;
    "kernel.sched_burst_penalty_scale" = 2048;
  };
}
