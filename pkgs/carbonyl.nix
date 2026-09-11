# Carbonyl — Chromium rendering into the terminal.
# Pre-built binary from fathyb/carbonyl v0.0.3 (Linux amd64).
#
# The upstream binary expects a full FHS environment (/usr/lib libs,
# /etc/pki, /usr/share). autoPatchelf satisfies the ELF dependencies but
# not the filesystem contract: NSS init and SwiftShader CHECK-crash
# (SIGTRAP -> wrapper exit 127) inside the GPU process. buildFHSEnv runs
# the pristine binary in the layout it was built for; children spawned
# by its re-exec self pattern inherit the mount namespace.
{
  lib,
  stdenv,
  fetchzip,
  buildFHSEnv,
  nss,
  nspr,
  alsa-lib,
  expat,
  fontconfig,
  freetype,
  glib,
  dbus,
  udev,
  mesa,
  libxkbcommon,
  xorg,
}:

let
  # Pristine upstream payload: binary, bundled libs and data files in one
  # flat directory. No ELF patching whatsoever — Chromium resolves
  # icudtl.dat and friends relative to the executable directory.
  carbonyl-unwrapped = stdenv.mkDerivation {
    pname = "carbonyl-unwrapped";
    version = "0.0.3";

    src = fetchzip {
      url = "https://github.com/fathyb/carbonyl/releases/download/v0.0.3/carbonyl.linux-amd64.zip";
      sha256 = "sha256-pKJdrs3UQyKZxQHeYuiBFBDjEgpHjurZVZDYWSYkinU=";
      stripRoot = false;
    };

    dontBuild = true;
    dontPatchELF = true;
    dontFixup = true;

    installPhase = ''
      # Older mirrors nested the payload under carbonyl-0.0.3/; the pinned
      # upload is flat. Detect, don't assume.
      srcRoot="$src/carbonyl-0.0.3"
      [[ -d "$srcRoot" ]] || srcRoot="$src"
      mkdir -p $out/lib/carbonyl $out/bin
      cp -r "$srcRoot"/. $out/lib/carbonyl/
      chmod +x $out/lib/carbonyl/carbonyl
      # /proc/self/exe resolves symlinks, so the exe dir stays
      # lib/carbonyl and the exe-relative data lookups work.
      ln -s ../lib/carbonyl/carbonyl $out/bin/carbonyl
    '';

    meta = with lib; {
      description = "Chromium running inside your terminal (unwrapped payload)";
      homepage = "https://github.com/fathyb/carbonyl";
      license = licenses.bsd2;
      platforms = [ "x86_64-linux" ];
    };
  };
in

buildFHSEnv {
  name = "carbonyl";
  version = "0.0.3";

  targetPkgs =
    pkgs': with pkgs'; [
      carbonyl-unwrapped
      # Runtime libs the prebuilt dlopens or links (libcarbonyl.so pulls
      # NSS/NSPR at init; the GPU process pulls the X11/GL stack).
      nss
      nspr
      alsa-lib
      expat
      fontconfig
      freetype
      glib
      dbus
      udev
      mesa # libgbm for the software compositing path
      xorg.libX11
      xorg.libxcb
      xorg.libXcomposite
      xorg.libXdamage
      xorg.libXext
      xorg.libXfixes
      xorg.libXrandr
      libxkbcommon
    ];

  runScript = "carbonyl";

  meta = with lib; {
    description = "Chromium running inside your terminal";
    homepage = "https://github.com/fathyb/carbonyl";
    license = licenses.bsd2;
    platforms = [ "x86_64-linux" ];
    mainProgram = "carbonyl";
  };
}
