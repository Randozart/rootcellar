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
  # carbonyl-0.0.3/ directory; older mirrors are flat. Detect, don't assume.
  installPhase = ''
    srcRoot="$src/carbonyl-0.0.3"
    [[ -d "$srcRoot" ]] || srcRoot="$src"
    # Flat install mirrors the upstream zip layout exactly: Chromium
    # resolves icudtl.dat, v8_context_snapshot.bin and the swiftshader ICD
    # relative to the executable directory, and dlopen() never looks there
    # — so the .so files live beside the binary AND on LD_LIBRARY_PATH.
    mkdir -p $out/bin
    cp -r "$srcRoot"/. $out/bin/
    chmod +x $out/bin/carbonyl
    wrapProgram $out/bin/carbonyl \
      --prefix LD_LIBRARY_PATH : "$out/bin:${lib.makeLibraryPath [ openssl nss alsa-lib expat fontconfig ]}"
  '';

  meta = with lib; {
    description = "Chromium running inside your terminal";
    homepage = "https://github.com/fathyb/carbonyl";
    license = licenses.bsd2;
    platforms = [ "x86_64-linux" ];
    mainProgram = "carbonyl";
  };
}
