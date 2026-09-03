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
  };
}
