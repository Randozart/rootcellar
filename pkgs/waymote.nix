# Waymote — H.264/Opus streaming of a wlroots desktop into the browser.
# Pre-built server binaries from rockorager/waymote v0.1.4 (linux x86-64).
#
# Two processes ship in the release tarball: waymote-gateway (static Go:
# HTTP + WebSocket, embeds the browser client UI) and waymote-streamd
# (Zig: Wayland capture, virtual input, output sizing). Only streamd is
# dynamically linked — autoPatchelf wires it to the Nix glibc, wayland
# and libxkbcommon; the gateway runs untouched. streamd supervises an
# `ffmpeg` from PATH for the libx264 encode, which the service unit
# provides.
{
  lib,
  stdenv,
  fetchzip,
  autoPatchelfHook,
  wayland,
  libxkbcommon,
}:

stdenv.mkDerivation {
  pname = "waymote";
  version = "0.1.4";

  src = fetchzip {
    url = "https://github.com/rockorager/waymote/releases/download/v0.1.4/waymote-server-0.1.4-linux-x86_64.tar.gz";
    sha256 = "sha256-fjgl/Sr4HBkz7Zk8kWrD9PDCLdM3TfH5ySmfqy4kNR8=";
  };

  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [
    wayland
    libxkbcommon
  ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    install -m0755 bin/waymote-gateway $out/bin/
    install -m0755 bin/waymote-streamd $out/bin/
    runHook postInstall
  '';

  meta = with lib; {
    description = "Low-latency H.264 streaming of a wlroots desktop to the browser";
    homepage = "https://github.com/rockorager/waymote";
    license = licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "waymote-gateway";
  };
}
