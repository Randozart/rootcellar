"""Wraps cellar CLI commands for the control center GUI."""

import json
import subprocess
from typing import Optional

from PySide6.QtCore import QObject, Signal, Slot


class CellarBackend(QObject):
    """Backend for cellar CLI operations (search, use, freeze, profile, etc.)."""
    
    searchResultsReady = Signal(str)  # JSON string of results
    operationFinished = Signal(bool, str)  # success, message
    profileReady = Signal(str)  # JSON string
    frozenReady = Signal(str)  # JSON string
    systemReady = Signal(str)  # TSV string
    
    def __init__(self, cellar_cmd: str = "cellar", parent=None):
        super().__init__(parent)
        self._cellar = cellar_cmd
    
    @Slot(str)
    def search(self, query: str):
        """Search nixpkgs via cellar search --json."""
        try:
            result = subprocess.run(
                [self._cellar, "search", "--json", query],
                capture_output=True, text=True, timeout=30
            )
            self.searchResultsReady.emit(result.stdout.strip() or "[]")
        except Exception as e:
            self.searchResultsReady.emit(f"[]")
    
    @Slot(str)
    def install(self, attr: str):
        """Install a package locally via cellar use."""
        try:
            result = subprocess.run(
                [self._cellar, "use", attr],
                capture_output=True, text=True, timeout=60
            )
            self.operationFinished.emit(
                result.returncode == 0,
                result.stdout.strip() if result.returncode == 0 else result.stderr.strip()
            )
        except Exception as e:
            self.operationFinished.emit(False, str(e))
    
    @Slot(str)
    def uninstall(self, attr: str):
        """Remove a local package via cellar unuse."""
        try:
            result = subprocess.run(
                [self._cellar, "unuse", attr],
                capture_output=True, text=True, timeout=30
            )
            self.operationFinished.emit(
                result.returncode == 0,
                result.stdout.strip() if result.returncode == 0 else result.stderr.strip()
            )
        except Exception as e:
            self.operationFinished.emit(False, str(e))
    
    @Slot(str)
    def freeze(self, attr: str):
        """Freeze a package into the declarative list."""
        try:
            result = subprocess.run(
                [self._cellar, "freeze", attr],
                capture_output=True, text=True, timeout=30
            )
            self.operationFinished.emit(
                result.returncode == 0,
                result.stdout.strip() if result.returncode == 0 else result.stderr.strip()
            )
        except Exception as e:
            self.operationFinished.emit(False, str(e))
    
    @Slot(str)
    def unfreeze(self, attr: str):
        """Unfreeze a package from the declarative list."""
        try:
            result = subprocess.run(
                [self._cellar, "unfreeze", attr],
                capture_output=True, text=True, timeout=30
            )
            self.operationFinished.emit(
                result.returncode == 0,
                result.stdout.strip() if result.returncode == 0 else result.stderr.strip()
            )
        except Exception as e:
            self.operationFinished.emit(False, str(e))
    
    @Slot()
    def loadProfile(self):
        """Load local packages (nix profile)."""
        try:
            result = subprocess.run(
                [self._cellar, "profile", "--json"],
                capture_output=True, text=True, timeout=15
            )
            self.profileReady.emit(result.stdout.strip() or "[]")
        except Exception:
            self.profileReady.emit("[]")
    
    @Slot()
    def loadFrozen(self):
        """Load frozen packages (user-packages.list)."""
        try:
            result = subprocess.run(
                [self._cellar, "frozen", "--json"],
                capture_output=True, text=True, timeout=15
            )
            self.frozenReady.emit(result.stdout.strip() or "[]")
        except Exception:
            self.frozenReady.emit("[]")
    
    @Slot()
    def loadSystem(self):
        """Load system packages manifest."""
        try:
            with open("/etc/xdg/cellar/system-packages", "r") as f:
                self.systemReady.emit(f.read())
        except Exception:
            self.systemReady.emit("")
    
    featuredReady = Signal(str)
    
    @Slot()
    def loadFeatured(self):
        """Load featured packages catalog."""
        try:
            with open("/etc/cellar/software-center/featured.toml", "r") as f:
                self.featuredReady.emit(f.read())
        except Exception:
            self.featuredReady.emit("")
