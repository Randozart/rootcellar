# Waymote — H.264/Opus streaming of a wlroots desktop into the browser.
# Two halves, two trust levels:
#
# - waymote-streamd (Zig: Wayland capture, virtual input, output
#   sizing) stays the PREBUILT release binary — autoPatchelf wires it
#   to the Nix glibc, wayland and libxkbcommon. It supervises an
#   `ffmpeg` from PATH for the x264 encode (the unit supplies a
#   wrapper that keeps RTP datagrams under the mirrored-loopback MTU).
# - waymote-gateway (Go: HTTP + WebSocket, embeds the browser client)
#   is BUILT FROM SOURCE at the same pinned tag, with the embedded demo
#   page replaced by the RootCellar client (deskbottom/waymote-client):
#   manual remoteDisplay policy, zero chrome, zero resize requests, so
#   the output stays exactly what the sway config pins. The go.mod
#   demands Go 1.26, which the stable pin does not carry — the flake
#   overlay passes the unstable buildGoModule in explicitly.
{
  lib,
  stdenv,
  fetchzip,
  buildGoModule,
  autoPatchelfHook,
  symlinkJoin,
  wayland,
  libxkbcommon,
}:

let
  version = "0.1.4";

  streamd = stdenv.mkDerivation {
    pname = "waymote-streamd";
    inherit version;

    src = fetchzip {
      url = "https://github.com/rockorager/waymote/releases/download/v${version}/waymote-server-${version}-linux-x86_64.tar.gz";
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
      install -m0755 bin/waymote-streamd $out/bin/
      runHook postInstall
    '';

    meta = with lib; {
      description = "Wayland capture/virtual-input daemon for waymote (prebuilt)";
      homepage = "https://github.com/rockorager/waymote";
      license = licenses.mit;
      platforms = [ "x86_64-linux" ];
    };
  };

  gateway = buildGoModule {
    pname = "waymote-gateway";
    inherit version;

    src = fetchzip {
      url = "https://github.com/rockorager/waymote/archive/refs/tags/v${version}.tar.gz";
      sha256 = "sha256-fNhHOSyhJMPlid15J4XGGk45VwMAw+eHOFVP845hj48=";
    };

    modRoot = "gateway";
    vendorHash = "sha256-dPqKr8BBaUATlcjlmD5S3VqrKqtAXQMKkRSTEur5yy4=";

    # Swap the embedded demo page for the RootCellar client before the
    # go:embed runs. Same origin as the WebSocket endpoints, so the
    # gateway's origin restriction needs no changes. postPatch runs at
    # the source root (patchPhase precedes the modRoot cd), in both the
    # main build and the go-modules vendoring build.
    postPatch = ''
      rm -rf gateway/examples/web
      mkdir -p gateway/examples/web
      cp ${../deskbottom/waymote-client}/* gateway/examples/web/
    '';

    env.CGO_ENABLED = "0";
    ldflags = [
      "-s"
      "-w"
      "-X main.version=${version}"
    ];

    postInstall = ''
      mv $out/bin/gateway $out/bin/waymote-gateway
    '';

    meta = with lib; {
      description = "Waymote gateway: HTTP + WebSocket bridge for the H.264 stream";
      homepage = "https://github.com/rockorager/waymote";
      license = licenses.mit;
      platforms = [ "x86_64-linux" ];
    };
  };
in
symlinkJoin {
  name = "waymote-${version}";
  paths = [
    gateway
    streamd
  ];

  meta = with lib; {
    description = "Low-latency H.264 streaming of a wlroots desktop to the browser";
    homepage = "https://github.com/rockorager/waymote";
    license = licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "waymote-gateway";
  };
}
