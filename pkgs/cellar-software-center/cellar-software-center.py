#!/usr/bin/env python3
"""Cellar Software Center — search nixpkgs, install locally or freeze in.

A thin GTK4/libadwaita front-end over the `cellar` verbs:

  local  — cellar use / cellar unuse        (nix profile, no rebuild)
  frozen — cellar freeze / cellar unfreeze  (modules/user-packages.list, git)
  deploy — sudo -S cellar deploy-root       (one password, then rebuild)

Every package is either local (this user's nix profile), frozen
(declarative, git-backed) or available. The flow: Install (try it now) →
Freeze in (make it permanent) → Deploy.

No secrets are logged; the sudo password is piped to `sudo -S` on stdin.
"""

import json
import os
import shutil
import subprocess
import threading
import tomllib

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
from gi.repository import GLib, Gtk, Adw  # noqa: E402

CELLAR_ETC = "/etc/cellar/cellar"
FEATURED_TOML = "/etc/cellar/software-center/featured.toml"
SYSTEM_LIST = "/etc/xdg/cellar/system-packages"


def cellar_path():
    if os.path.exists(CELLAR_ETC):
        return CELLAR_ETC
    return shutil.which("cellar") or CELLAR_ETC


def run(args, input_text=None):
    try:
        return subprocess.run(
            args, capture_output=True, text=True, input=input_text, timeout=900
        )
    except Exception as exc:  # noqa: BLE001
        return subprocess.CompletedProcess(args, 127, "", f"run failed: {exc}")


def run_json(args):
    result = run(args)
    try:
        return json.loads(result.stdout or "[]")
    except Exception:  # noqa: BLE001
        return []


def load_featured():
    try:
        with open(FEATURED_TOML, "rb") as fh:
            data = tomllib.load(fh)
        return data.get("featured", [])
    except Exception:  # noqa: BLE001
        return []


def load_system_packages():
    """(name, description) for everything in the current system closure.

    The manifest is generated at system-eval time: name TAB description.
    """
    try:
        with open(SYSTEM_LIST) as fh:
            rows = []
            for line in fh:
                name, _, desc = line.rstrip("\n").partition("\t")
                if name:
                    rows.append((name, desc))
            return rows
    except Exception:  # noqa: BLE001
        return []


def load_system_set():
    """Everything that counts as 'already on the system'.

    Closure package names plus every command in the system profile: a
    wrapped package's command is what search results surface (gcc, not
    gcc-wrapper), so the command namespace is what users actually meet.
    """
    names = {name for name, _ in load_system_packages()}
    try:
        names |= {e for e in os.listdir("/run/current-system/sw/bin") if e}
    except Exception:  # noqa: BLE001
        pass
    return names


class PackageRow(Adw.ActionRow):
    """One package with state-dependent action buttons."""

    def __init__(self, attr, title, subtitle, local, frozen, system, callbacks):
        super().__init__()
        self.attr = attr
        self.set_title(title or attr)
        if subtitle:
            self.set_subtitle(subtitle)

        self._badge = Gtk.Label()
        self._badge.add_css_class("dim-label")

        self._btn_install = Gtk.Button(label="Install")
        self._btn_install.add_css_class("suggested-action")
        self._btn_install.connect("clicked", lambda _b: callbacks["install"](attr))

        self._btn_remove = Gtk.Button(label="Remove")
        self._btn_remove.add_css_class("destructive-action")
        self._btn_remove.connect("clicked", lambda _b: callbacks["remove"](attr))

        self._btn_freeze = Gtk.Button(label="Freeze in")
        self._btn_freeze.connect("clicked", lambda _b: callbacks["freeze"](attr))

        self._btn_unfreeze = Gtk.Button(label="Unfreeze")
        self._btn_unfreeze.connect("clicked", lambda _b: callbacks["unfreeze"](attr))

        self.refresh(local, frozen, system)

    def refresh(self, local, frozen, system):
        tags = []
        if system:
            tags.append("system")
        if frozen:
            tags.append("frozen")
        if local:
            tags.append("local")
        self._badge.set_text(" · ".join(tags))

        for w in self._suffixes():
            self.remove(w)

        self.add_suffix(self._badge)
        if local:
            self.add_suffix(self._btn_remove)
        else:
            self.add_suffix(self._btn_install)
        if frozen:
            self.add_suffix(self._btn_unfreeze)
        elif not system:
            # A system package is already in the flake; freezing it into
            # user-packages.list would only duplicate the declaration.
            self.add_suffix(self._btn_freeze)

    def _suffixes(self):
        return [self._badge, self._btn_install, self._btn_remove,
                self._btn_freeze, self._btn_unfreeze]


class ProgressWindow(Adw.Window):
    """Modal spinner window shown while package operations run.

    One instance is shared; concurrent operations stack (push/pop) so the
    window stays up until the last one finishes.
    """

    def __init__(self, parent):
        super().__init__(transient_for=parent, modal=True, deletable=False)
        self.set_default_size(400, -1)
        self._depth = 0

        box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        for margin in ("top", "bottom", "start", "end"):
            getattr(box, f"set_margin_{margin}")(18)
        self._spinner = Gtk.Spinner()
        self._label = Gtk.Label(wrap=True, xalign=0.0, hexpand=True)
        box.append(self._spinner)
        box.append(self._label)
        self.set_content(box)

    def push(self, message):
        self._depth += 1
        self._label.set_text(message)
        self._spinner.start()
        self.present()

    def pop(self):
        self._depth = max(0, self._depth - 1)
        if self._depth == 0:
            self._spinner.stop()
            self.close()


class SoftwareCenterWindow(Adw.ApplicationWindow):
    def __init__(self, app):
        super().__init__(application=app)
        self.set_title("Software Center")
        self.set_default_size(900, 620)
        self._featured = load_featured()
        self._local = {}   # attr -> info
        self._frozen = set()
        self._system = set()
        self._search_results = []

        self._callbacks = {
            "install": self.install_local,
            "remove": self.remove_local,
            "freeze": self.freeze_in,
            "unfreeze": self.unfreeze,
        }

        # --- state + toast overlay ---
        self._toast = Adw.ToastOverlay()

        # --- header ---
        header = Adw.HeaderBar()
        deploy_btn = Gtk.Button(label="Deploy")
        deploy_btn.add_css_class("suggested-action")
        deploy_btn.connect("clicked", self._on_deploy)
        header.pack_end(deploy_btn)

        switcher = Adw.ViewSwitcher()
        switcher.set_policy(Adw.ViewSwitcherPolicy.WIDE)

        # --- pages ---
        self._stack = Adw.ViewStack()
        self._stack.connect("notify::visible-child", self._on_page_changed)
        switcher.set_stack(self._stack)
        header.set_title_widget(switcher)

        self._list_featured = Gtk.ListBox()
        self._list_featured.set_selection_mode(Gtk.SelectionMode.NONE)
        self._list_local = Gtk.ListBox()
        self._list_local.set_selection_mode(Gtk.SelectionMode.NONE)
        self._list_frozen = Gtk.ListBox()
        self._list_frozen.set_selection_mode(Gtk.SelectionMode.NONE)
        self._list_search = Gtk.ListBox()
        self._list_search.set_selection_mode(Gtk.SelectionMode.NONE)
        self._list_system = Gtk.ListBox()
        self._list_system.set_selection_mode(Gtk.SelectionMode.NONE)

        self._add_page("Featured", "emblem-favorite", self._scrolled(self._list_featured))
        self._add_page("Search", "system-search", self._build_search_page())
        self._add_page("System", "applications-system", self._scrolled(self._list_system))
        self._add_page("Local", "package", self._scrolled(self._list_local))
        self._add_page("Frozen", "emblem-default", self._scrolled(self._list_frozen))

        content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        content.append(header)
        content.append(self._stack)

        self._toast.set_child(content)
        self.set_content(self._toast)

        self._progress = ProgressWindow(self)
        self.refresh_state()

    # ---- helpers ----

    def _add_page(self, title, icon, widget):
        page = self._stack.add_titled(widget, title.lower(), title)
        page.set_icon_name(icon)

    @staticmethod
    def _scrolled(listbox):
        sc = Gtk.ScrolledWindow()
        sc.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        sc.set_vexpand(True)
        sc.set_child(listbox)
        return sc

    def _build_search_page(self):
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        self._search_entry = Gtk.SearchEntry()
        self._search_entry.set_placeholder_text("Search nixpkgs…")
        self._search_entry.connect("activate", self._on_search)
        self._search_spinner = Gtk.Spinner()
        self._search_spinner.set_visible(False)
        row.append(self._search_entry)
        row.append(self._search_spinner)
        box.append(row)
        box.append(self._scrolled(self._list_search))
        return box

    # ---- state ----

    def refresh_state(self):
        def load():
            local = {p["name"]: p for p in run_json([cellar_path(), "profile", "--json"])}
            frozen = set(run_json([cellar_path(), "frozen", "--json"]))
            system = load_system_set()
            GLib.idle_add(self._apply_state, local, frozen, system)

        threading.Thread(target=load, daemon=True).start()

    def _apply_state(self, local, frozen, system):
        self._local = local
        self._frozen = frozen
        self._system = system
        self._render_featured()
        self._render_system()
        self._render_local()
        self._render_frozen()
        if self._stack.get_visible_child_name() == "search" and self._search_results:
            self._render_search()

    # ---- renderers ----

    def _clear_list(self, listbox):
        while (child := listbox.get_first_child()) is not None:
            listbox.remove(child)

    def _row(self, attr, title, subtitle, local, frozen):
        return PackageRow(
            attr, title, subtitle, local, frozen, attr in self._system, self._callbacks
        )

    def _render_featured(self):
        self._clear_list(self._list_featured)
        for item in self._featured:
            attr = item["attr"]
            row = self._row(
                attr,
                item.get("title") or attr,
                item.get("description") or f"nixpkgs#{attr}",
                attr in self._local,
                attr in self._frozen,
            )
            self._list_featured.append(row)

    def _render_system(self):
        self._clear_list(self._list_system)
        for name, desc in load_system_packages():
            row = self._row(name, name, desc or "part of the system closure",
                            name in self._local, False)
            self._list_system.append(row)

    def _render_local(self):
        self._clear_list(self._list_local)
        for name, info in sorted(self._local.items()):
            row = self._row(name, name, info.get("url") or "", True, name in self._frozen)
            self._list_local.append(row)

    def _render_frozen(self):
        self._clear_list(self._list_frozen)
        for name in sorted(self._frozen):
            row = self._row(name, name, "modules/user-packages.list", name in self._local, True)
            self._list_frozen.append(row)

    def _render_search(self):
        self._clear_list(self._list_search)
        for item in self._search_results:
            attr = item.get("attr", "")
            if not attr:
                continue
            row = self._row(
                attr,
                item.get("pname") or attr,
                item.get("description") or "",
                attr in self._local,
                attr in self._frozen,
            )
            self._list_search.append(row)

    def _on_page_changed(self, *_):
        if self._stack.get_visible_child_name() == "search":
            self._search_entry.grab_focus()

    # ---- search ----

    def _on_search(self, _entry):
        query = self._search_entry.get_text().strip()
        if not query:
            return
        self._search_spinner.set_visible(True)
        self._search_spinner.start()

        def search():
            results = run_json([cellar_path(), "search", "--json", query])
            GLib.idle_add(self._search_done, results)

        threading.Thread(target=search, daemon=True).start()

    def _search_done(self, results):
        self._search_spinner.stop()
        self._search_spinner.set_visible(False)
        self._search_results = results
        self._render_search()

    # ---- actions ----

    def _action(self, args, message):
        # Modal spinner while the verb runs; the cellar call can take a
        # while (nix profile evaluates, freeze commits) and silence reads
        # as "the app hung".
        self._progress.push(f"{message}…")

        def worker():
            result = run(args)
            GLib.idle_add(self._action_done, message, result)

        threading.Thread(target=worker, daemon=True).start()

    def _action_done(self, message, result):
        self._progress.pop()
        detail = (result.stdout or "").strip() or (result.stderr or "").strip()
        if result.returncode != 0:
            self._toast_say(f"{message} failed: {detail or 'unknown error'}")
        else:
            self._toast_say(f"{message}: done")
        self.refresh_state()

    def install_local(self, attr):
        self._action([cellar_path(), "use", attr], f"Installed {attr}")

    def remove_local(self, attr):
        self._action([cellar_path(), "unuse", attr], f"Removed {attr}")

    def freeze_in(self, attr):
        self._action([cellar_path(), "freeze", attr], f"Frozen {attr}")

    def unfreeze(self, attr):
        self._action([cellar_path(), "unfreeze", attr], f"Unfrozen {attr}")

    # ---- deploy ----

    def _on_deploy(self, _btn):
        dialog = Adw.MessageDialog.new(
            self,
            "Deploy frozen changes",
            "This rebuilds the system from the flake. Only your sudo password "
            "is needed — it is sent straight to sudo and never stored.",
        )
        pw = Gtk.PasswordEntry()
        pw.set_placeholder_text("sudo password")
        dialog.set_extra_child(pw)
        dialog.add_response("cancel", "Cancel")
        dialog.add_response("deploy", "Deploy")
        dialog.set_default_response("deploy")
        dialog.set_response_appearance("deploy", Adw.ResponseAppearance.SUGGESTED)
        dialog.connect("response", self._on_deploy_response, pw)
        dialog.present()

    def _on_deploy_response(self, dialog, response, pw):
        if response != "deploy":
            return
        password = pw.get_text()
        pw.set_text("")
        dialog.close()
        self._toast_say("Deploying… this can take a while")
        threading.Thread(target=self._deploy_worker, args=(password,), daemon=True).start()

    def _deploy_worker(self, password):
        root = run([cellar_path(), "deploy-root"], input_text=password + "\n")
        del password
        user = run([cellar_path(), "deploy-user"])
        ok = root.returncode == 0 and user.returncode == 0
        tail = (root.stderr or "")[-600:].strip()
        GLib.idle_add(self._deploy_done, ok, tail)

    def _deploy_done(self, ok, tail):
        if ok:
            self._toast_say("Deployed. Changes are now part of the system.")
        else:
            self._toast_say(f"Deploy failed: {tail or 'see terminal for details'}")
        self.refresh_state()

    def _toast_say(self, message):
        self._toast.add_toast(Adw.Toast.new(message))


class SoftwareCenterApp(Adw.Application):
    def __init__(self):
        super().__init__(application_id="dev.rootcellar.softwarecenter")
        self.connect("activate", self.on_activate)

    def on_activate(self, app):
        win = self._win if hasattr(self, "_win") else None
        if win is None:
            win = SoftwareCenterWindow(app)
            self._win = win
        win.present()


def main():
    app = SoftwareCenterApp()
    app.run(None)


if __name__ == "__main__":
    main()