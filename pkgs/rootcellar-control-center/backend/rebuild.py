"""NixOS rebuild operations with live progress tracking."""

import json
import os
import re
import subprocess
import threading
from typing import Optional

from PySide6.QtCore import QObject, Signal, Slot


class RebuildBackend(QObject):
    """Backend for nixos-rebuild with progress and diff."""
    
    progressUpdated = Signal(int, str)  # percentage, status message
    buildLogLine = Signal(str)  # raw build log line
    diffReady = Signal(str)  # formatted diff output
    rebuildFinished = Signal(bool, str)  # success, message
    serviceReloadReady = Signal(str)  # JSON list of services to reload
    operationFinished = Signal(bool, str)
    
    def __init__(self, repo_path: str, parent=None):
        super().__init__(parent)
        self._repo = repo_path
        self._process: Optional[subprocess.Popen] = None
        self._cancelled = False
    
    @Slot()
    def computeDiff(self):
        """Build the new toplevel and diff against current system."""
        self.progressUpdated.emit(0, "Evaluating new configuration...")
        
        def _worker():
            try:
                # Get current system path
                current = os.readlink("/run/current-system")
                
                # Build the new toplevel (dry, just evaluate + build)
                self.progressUpdated.emit(10, "Building new configuration (may take a while)...")
                build_result = subprocess.run(
                    ["nix", "build", "--print-out-paths",
                     f"{self._repo}#nixosConfigurations.rootcellar.config.system.build.toplevel"],
                    capture_output=True, text=True, timeout=600
                )
                
                if build_result.returncode != 0:
                    self.rebuildFinished.emit(False, f"Build failed: {build_result.stderr[:500]}")
                    return
                
                new_path = build_result.stdout.strip()
                if not new_path:
                    self.rebuildFinished.emit(False, "Build produced no output")
                    return
                
                self.progressUpdated.emit(70, "Computing closure diff...")
                
                # Diff closures
                diff_result = subprocess.run(
                    ["nix", "store", "diff-closures", current, new_path],
                    capture_output=True, text=True, timeout=60
                )
                
                diff_text = diff_result.stdout.strip() if diff_result.returncode == 0 else "(no changes)"
                self.diffReady.emit(diff_text)
                self.progressUpdated.emit(100, "Diff ready")
                
            except subprocess.TimeoutExpired:
                self.rebuildFinished.emit(False, "Build timed out after 10 minutes")
            except Exception as e:
                self.rebuildFinished.emit(False, str(e))
        
        thread = threading.Thread(target=_worker, daemon=True)
        thread.start()
    
    @Slot()
    def deploy(self):
        """Run the full deploy: sudo cellar deploy-root + cellar deploy-user."""
        self._cancelled = False
        self.progressUpdated.emit(0, "Starting deploy...")
        
        def _worker():
            try:
                # Phase 1: deploy-root via pkexec (polkit GUI prompt)
                self.progressUpdated.emit(5, "Authenticating...")
                root_result = subprocess.run(
                    ["pkexec", "cellar", "deploy-root"],
                    capture_output=True, text=True, timeout=600
                )
                
                if self._cancelled:
                    self.rebuildFinished.emit(False, "Cancelled")
                    return
                
                if root_result.returncode != 0:
                    self.rebuildFinished.emit(False, f"Deploy failed: {root_result.stderr[:500]}")
                    return
                
                self.progressUpdated.emit(80, "Rebuild complete. Reloading services...")
                
                # Phase 2: deploy-user (runs as current user)
                user_result = subprocess.run(
                    ["cellar", "deploy-user"],
                    capture_output=True, text=True, timeout=60
                )
                
                self.progressUpdated.emit(100, "Deploy complete")
                self.rebuildFinished.emit(True, "Rebuild successful")
                
            except subprocess.TimeoutExpired:
                self.rebuildFinished.emit(False, "Deploy timed out")
            except Exception as e:
                self.rebuildFinished.emit(False, str(e))
        
        thread = threading.Thread(target=_worker, daemon=True)
        thread.start()
    
    @Slot()
    def cancel(self):
        """Cancel the current rebuild."""
        self._cancelled = True
        if self._process:
            self._process.terminate()
    
    @Slot()
    def loadServices(self):
        """List running user services that can be reloaded."""
        try:
            result = subprocess.run(
                ["systemctl", "--user", "list-units", "--type=service",
                 "--state=running", "--plain", "--no-legend", "--json=short"],
                capture_output=True, text=True, timeout=10
            )
            if result.returncode == 0:
                data = json.loads(result.stdout)
                units = data.get("units", [])
                services = []
                for u in units:
                    name = u.get("unit", "")
                    # Filter to reloadable services
                    if any(s in name for s in ["plasma", "sway", "kwin", "waybar", "mako", "pipewire", "cellar"]):
                        services.append({
                            "name": name,
                            "canAutoReload": any(s in name for s in ["plasma", "kwin", "cellar"]),
                        })
                self.serviceReloadReady.emit(json.dumps(services))
            else:
                self.serviceReloadReady.emit("[]")
        except Exception:
            self.serviceReloadReady.emit("[]")
    
    @Slot(str)
    def reloadService(self, service_name: str):
        """Reload a specific user service."""
        try:
            # Determine reload method
            if "waybar" in service_name:
                subprocess.run(["bash", "-c", "killall -SIGUSR2 waybar"],
                             timeout=10)
            elif "mako" in service_name:
                subprocess.run(["makoctl", "reload"], timeout=10)
            else:
                subprocess.run(
                    ["systemctl", "--user", "restart", service_name],
                    timeout=30
                )
            self.operationFinished.emit(True, f"Reloaded {service_name}")
        except Exception as e:
            self.operationFinished.emit(False, f"Failed to reload {service_name}: {e}")
