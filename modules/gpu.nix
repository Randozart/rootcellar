# GPU passthrough plumbing. The NVIDIA *driver* always comes from Windows;
# never install a Linux driver inside WSL — it fights the passthrough stubs.
#
# Only the CUDA *toolkit* is installed inside the cellar. Enable with:
#   cellar.cuda.enable = true;
#
# LD_LIBRARY_PATH ordering is the classic footgun: the toolkit's lib64 must
# come BEFORE the WSL stub dir /usr/lib/wsl/lib, otherwise you get
# "libcuda.so version mismatch" at runtime.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cellar.cuda;

  cudaToolkit =
    if cfg.version != "" then
      pkgs."cudaPackages_${lib.replaceStrings [ "." ] [ "_" ] cfg.version}".cuda_nvcc
    else
      pkgs.cudaPackages.cuda_nvcc;
in
{
  options.cellar.cuda = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Install the CUDA toolkit (not the driver) and wire up environment paths.";
    };

    version = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = ''
        Optional pinned major.minor of the CUDA toolkit, e.g. "12.8".
        Empty string tracks the default cudaPackages in nixpkgs.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cudaToolkit ];

    environment.shellInit = ''
      # WSL driver stubs must be findable, but toolkit libs take precedence.
      export LD_LIBRARY_PATH="''${CUDA_HOME:+$CUDA_HOME/lib64:}$LD_LIBRARY_PATH:/usr/lib/wsl/lib"
    '';
  };
}
