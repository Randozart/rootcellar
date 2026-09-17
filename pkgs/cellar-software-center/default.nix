# Cellar Software Center — a GTK4/libadwaita front-end over `cellar` verbs
# for installing packages locally (nix profile) or freezing them into the
# declarative list. Pure Python + PyGObject; no compilation.
{
  stdenv,
  lib,
  python3,
  gtk4,
  libadwaita,
  gobject-introspection,
  wrapGAppsHook4,
  glib,
}:

let
  pyenv = python3.withPackages (ps: [ ps.pygobject3 ]);
in
stdenv.mkDerivation {
  pname = "cellar-software-center";
  version = "0.1.0";
  src = lib.cleanSource ./.;

  nativeBuildInputs = [ wrapGAppsHook4 ];
  buildInputs = [
    gtk4
    libadwaita
    gobject-introspection
    glib
  ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin $out/share/applications
    install -Dm755 cellar-software-center.py $out/bin/cellar-software-center
    install -Dm644 cellar-software-center.desktop $out/share/applications/
    runHook postInstall
  '';

  preFixup = ''
    # Run through the pyenv interpreter so PyGObject is importable;
    # wrapGAppsHook4 then sets GI_TYPELIB_PATH for GTK4/libadwaita.
    substituteInPlace $out/bin/cellar-software-center \
      --replace-fail "#!/usr/bin/env python3" "#!${pyenv}/bin/python3"
  '';

  meta = {
    description = "Visual software center: install locally or freeze into the flake";
    homepage = "https://github.com/Randozart/rootcellar";
    license = lib.licenses.mit;
    mainProgram = "cellar-software-center";
    platforms = lib.platforms.linux;
  };
}