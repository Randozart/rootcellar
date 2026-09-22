"""Flake introspection and hot-swap operations."""

import json
import subprocess
import time
from datetime import datetime, timezone
from typing import Optional

from PySide6.QtCore import QObject, Signal, Slot


class FlakeBackend(QObject):
    """Backend for nix flake operations (metadata, update, pin)."""
    
    metadataReady = Signal(str)  # JSON string of flake metadata
    operationFinished = Signal(bool, str)  # success, message
    inputUpdated = Signal(str, str)  # input_name, new_rev
    costWarning = Signal(str)  # warning message
    
    def __init__(self, repo_path: str, parent=None):
        super().__init__(parent)
        self._repo = repo_path
    
    @Slot()
    def loadMetadata(self):
        """Load flake metadata via nix flake metadata --json."""
        try:
            result = subprocess.run(
                ["nix", "flake", "metadata", "--json", self._repo],
                capture_output=True, text=True, timeout=30
            )
            if result.returncode == 0:
                self.metadataReady.emit(result.stdout.strip())
            else:
                self.metadataReady.emit("{}")
        except Exception:
            self.metadataReady.emit("{}")
    
    @Slot(str)
    def updateInput(self, input_name: str):
        """Update a single flake input to latest."""
        try:
            result = subprocess.run(
                ["nix", "flake", "update", input_name, "--flake", self._repo],
                capture_output=True, text=True, timeout=120
            )
            if result.returncode == 0:
                self.operationFinished.emit(True, f"Updated {input_name}")
                self.inputUpdated.emit(input_name, "")
                self.loadMetadata()
            else:
                self.operationFinished.emit(False, result.stderr.strip())
        except Exception as e:
            self.operationFinished.emit(False, str(e))
    
    @Slot(str, str)
    def pinInput(self, input_name: str, rev: str):
        """Pin a flake input to a specific revision."""
        try:
            url = f"github:NixOS/nixpkgs/{rev}"
            if "wsl" in input_name.lower():
                url = f"github:nix-community/NixOS-WSL/{rev}"
            result = subprocess.run(
                ["nix", "flake", "lock", "--override-input", input_name, url, self._repo],
                capture_output=True, text=True, timeout=120
            )
            if result.returncode == 0:
                self.operationFinished.emit(True, f"Pinned {input_name} to {rev[:12]}")
                self.inputUpdated.emit(input_name, rev)
                self.loadMetadata()
            else:
                self.operationFinished.emit(False, result.stderr.strip())
        except Exception as e:
            self.operationFinished.emit(False, str(e))
    
    @Slot(str)
    def switchBranch(self, input_name: str, branch: str):
        """Switch a flake input to a different branch."""
        try:
            url = f"github:NixOS/nixpkgs/{branch}"
            if "wsl" in input_name.lower():
                url = f"github:nix-community/NixOS-WSL/{branch}"
            result = subprocess.run(
                ["nix", "flake", "lock", "--override-input", input_name, url, self._repo],
                capture_output=True, text=True, timeout=120
            )
            if result.returncode == 0:
                self.operationFinished.emit(True, f"Switched {input_name} to {branch}")
                self.inputUpdated.emit(input_name, "")
                self.loadMetadata()
            else:
                self.operationFinished.emit(False, result.stderr.strip())
        except Exception as e:
            self.operationFinished.emit(False, str(e))
    
    @Slot(str)
    def showCostWarning(self, input_name: str):
        """Show cost warning for updating a major input."""
        if "nixpkgs" in input_name and "unstable" not in input_name:
            self.costWarning.emit(
                "Updating nixpkgs will require rebuilding sway, wlroots, "
                "and all packages built against the old pin. This may take "
                "10-30 minutes depending on your machine."
            )
        elif "wsl" in input_name.lower():
            self.costWarning.emit(
                "Updating nixos-wsl changes WSL integration modules. "
                "A rebuild is required but typically fast."
            )
