"""Systemd user service management for live reload after rebuild."""

import json
import subprocess
from typing import Optional

from PySide6.QtCore import QObject, Signal, Slot


class ServiceBackend(QObject):
    """Backend for managing systemd user services."""
    
    servicesReady = Signal(str)  # JSON list of services
    reloadFinished = Signal(bool, str)  # success, message
    
    @Slot()
    def listRunning(self):
        """List running user services."""
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
                    # Only show relevant services
                    if any(s in name for s in [
                        "plasma", "sway", "kwin", "waybar", "mako",
                        "pipewire", "cellar", "gammastep", "swayidle"
                    ]):
                        can_auto = any(s in name for s in [
                            "plasma", "kwin", "cellar", "pipewire"
                        ])
                        services.append({
                            "name": name,
                            "displayName": name.replace(".service", "").replace("plasma-", "Plasma: ").replace("cellar-", "Cellar: "),
                            "canAutoReload": can_auto,
                        })
                self.servicesReady.emit(json.dumps(services))
            else:
                self.servicesReady.emit("[]")
        except Exception:
            self.servicesReady.emit("[]")
    
    @Slot(str)
    def restart(self, service_name: str):
        """Restart a user service."""
        try:
            result = subprocess.run(
                ["systemctl", "--user", "restart", service_name],
                capture_output=True, text=True, timeout=30
            )
            self.reloadFinished.emit(
                result.returncode == 0,
                f"Restarted {service_name}" if result.returncode == 0
                else f"Failed: {result.stderr.strip()}"
            )
        except Exception as e:
            self.reloadFinished.emit(False, str(e))
    
    @Slot(str)
    def reload(self, service_name: str):
        """Reload a user service (signal-based where possible)."""
        try:
            if "waybar" in service_name:
                subprocess.run(["bash", "-c", "killall -SIGUSR2 waybar"],
                             capture_output=True, timeout=10)
                self.reloadFinished.emit(True, "Sent SIGUSR2 to waybar")
            elif "mako" in service_name:
                subprocess.run(["makoctl", "reload"],
                             capture_output=True, timeout=10)
                self.reloadFinished.emit(True, "Reloaded mako")
            else:
                result = subprocess.run(
                    ["systemctl", "--user", "reload", service_name],
                    capture_output=True, text=True, timeout=30
                )
                self.reloadFinished.emit(
                    result.returncode == 0,
                    f"Reloaded {service_name}" if result.returncode == 0
                    else f"Failed: {result.stderr.strip()}"
                )
        except Exception as e:
            self.reloadFinished.emit(False, str(e))
    
    @Slot()
    def daemonReload(self):
        """Run systemctl --user daemon-reload."""
        try:
            subprocess.run(
                ["systemctl", "--user", "daemon-reload"],
                capture_output=True, timeout=10
            )
            self.reloadFinished.emit(True, "Daemon reloaded")
        except Exception as e:
            self.reloadFinished.emit(False, str(e))
