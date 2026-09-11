# Carbonyl — Chromium rendering into the terminal.
# Pre-built binary from fathyb/carbonyl v0.0.3 (Linux amd64).
{
  lib,
  stdenv,
  fetchzip,
  autoPatchelfHook,
  openssl,
  nss,
  alsa-lib,
  expat,
  fontconfig,
  xorg,
  makeWrapper,
}:

stdenv.mkDerivation {
  pname = "carbonyl";
  version = "0.0.3";

  src = fetchzip {
    url = "https://github.com/fathyb/carbonyl/releases/download/v0.0.3/carbonyl.linux-amd64.zip";
    sha256 = "sha256-pKJdrs3UQyKZxQHeYuiBFBDjEgpHjurZVZDYWSYkinU=";
    stripRoot = false;
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [
    openssl
    nss
    alsa-lib
    expat
    fontconfig
    xorg.libX11
    xorg.libXcomposite
    xorg.libXdamage
    xorg.libXext
    xorg.libXfixes
    xorg.libXrandr
    xorg.libxcb
  ];

  # autoPatchelfHook needs this to find the interpreter and libs
  autoPatchelfIgnoreMissingDeps = [
    "libffmpeg.so"
  ];

  dontBuild = true;

  # Upstream re-uploaded the v0.0.3 zip with everything nested under a
  # carbonyl-0.0.3/ directory (stripRoot=false keeps it). Address the
  # release payload through $src rather than a detected source root.
  installPhase = ''
    mkdir -p $out/bin $out/lib/carbonyl
    cp "$src/carbonyl-0.0.3/carbonyl" $out/bin/carbonyl
    chmod +x $out/bin/carbonyl
    # Copy shared libraries and data files carbonyl needs at runtime
    cp "$src/carbonyl-0.0.3/libcarbonyl.so" $out/lib/carbonyl/
    cp "$src"/carbonyl-0.0.3/*.dat $out/lib/carbonyl/ 2>/dev/null || true
    cp "$src"/carbonyl-0.0.3/*.json $out/lib/carbonyl/ 2>/dev/null || true
    cp "$src/carbonyl-0.0.3/v8_context_snapshot.bin" $out/lib/carbonyl/ 2>/dev/null || true
    # Wrap the binary to find its libraries
    wrapProgram $out/bin/carbonyl \
      --prefix LD_LIBRARY_PATH : "$out/lib/carbonyl:${lib.makeLibraryPath [ openssl nss alsa-lib expat fontconfig ]}"
  '';

  meta = with lib; {
    description = "Chromium running inside your terminal";
    homepage = "https://github.com/fathyb/carbonyl";
    license = licenses.bsd2;
    platforms = [ "x86_64-linux" ];
    mainProgram = "carbonyl";
  };
}
