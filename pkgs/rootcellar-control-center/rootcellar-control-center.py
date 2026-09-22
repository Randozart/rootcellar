#!/usr/bin/env python3
"""RootCellar Control Center — packages, flake, rebuild, settings."""

import os
import sys

from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtCore import QUrl

# Add backend to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from backend.cellar import CellarBackend
from backend.flake import FlakeBackend
from backend.rebuild import RebuildBackend
from backend.services import ServiceBackend


def main():
    app = QGuiApplication(sys.argv)
    app.setApplicationName("RootCellar Control Center")
    app.setOrganizationName("rootcellar")
    app.setApplicationDisplayName("RootCellar Control Center")

    # Determine repo path
    repo = os.environ.get(
        "CELLAR_REPO",
        os.path.expanduser("~/Documents/Projects/rootcellar")
    )
    if not os.path.isdir(repo):
        # Try the Windows-side path
        repo = "/mnt/c/Users/randy/Documents/Projects/rootcellar"

    # Create backends
    cellar = CellarBackend()
    flake = FlakeBackend(repo)
    rebuild = RebuildBackend(repo)
    services = ServiceBackend()

    # Create QML engine and expose backends
    engine = QQmlApplicationEngine()
    engine.rootContext().setContextProperty("cellarBackend", cellar)
    engine.rootContext().setContextProperty("flakeBackend", flake)
    engine.rootContext().setContextProperty("rebuildBackend", rebuild)
    engine.rootContext().setContextProperty("serviceBackend", services)

    # Load QML
    qml_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "qml")
    engine.load(QUrl.fromLocalFile(os.path.join(qml_dir, "main.qml")))

    if not engine.rootObjects():
        print("Failed to load QML", file=sys.stderr)
        sys.exit(1)

    sys.exit(app.exec())


if __name__ == "__main__":
    main()
