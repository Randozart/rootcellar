# RootCellar Control Center — Qt6/QML replacement for the GTK4 software center.
# Packages, flake introspection, system rebuild with live progress, and settings.
{
  stdenv,
  lib,
  python3,
  qt6,
}:

let
  pyenv = python3.withPackages (ps: [ ps.pyside6 ]);
in
stdenv.mkDerivation {
  pname = "rootcellar-control-center";
  version = "0.1.0";
  src = lib.cleanSource ./.;

  nativeBuildInputs = [ qt6.wrapQtAppsHook ];
  buildInputs = [
    qt6.qtbase
    qt6.qtdeclarative
    qt6.qtwayland
  ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin $out/share/applications $out/share/rootcellar-control-center/qml
    mkdir -p $out/share/rootcellar-control-center/backend
    install -Dm755 rootcellar-control-center.py $out/bin/rootcellar-control-center
    cp -r qml/* $out/share/rootcellar-control-center/qml/
    cp backend/*.py $out/share/rootcellar-control-center/backend/
    touch $out/share/rootcellar-control-center/backend/__init__.py
    install -Dm644 rootcellar-control-center.desktop $out/share/applications/
    install -Dm644 rootcellar-control-center.appdata.xml $out/share/metainfo/ 2>/dev/null || true
    runHook postInstall
  '';

  preFixup = ''
    # Run through pyenv so PySide6 is importable; wrapQtAppsHook sets
    # QT_PLUGIN_PATH and QML2_IMPORT_PATH for Qt6.
    wrapQtApp $out/bin/rootcellar-control-center \
      --prefix PYTHONPATH : "${pyenv}/${pyenv.python.sitePackages}" \
      --set QML_IMPORT_PATH "$out/share/rootcellar-control-center/qml"
  '';

  meta = {
    description = "RootCellar Control Center — packages, flake, rebuild, settings";
    homepage = "https://github.com/Randozart/rootcellar";
    license = lib.licenses.mit;
    mainProgram = "rootcellar-control-center";
    platforms = lib.platforms.linux;
  };
}
