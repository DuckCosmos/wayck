import os
import re
import shlex
import shutil
import subprocess
from pathlib import Path
import utils

class AppData:
    __slots__ = ("nome", "icone_path", "exec")
    def __init__(self, nome, icone_path, exec_command):
        self.nome = nome
        self.icone_path = icone_path
        self.exec = exec_command
    def as_dict(self):
        return {"nome": self.nome, "icone_path": self.icone_path, "exec": self.exec}

def _application_dirs():
    home = Path.home()
    return (
        Path("/usr/share/applications"),
        Path("/usr/local/share/applications"),
        Path("/var/lib/flatpak/exports/share/applications"),
        home / ".local/share/applications",
        home / ".local/share/flatpak/exports/share/applications",
    )

def _icon_path(icon):
    if not icon:
        return ""
    candidate = Path(icon).expanduser()
    if candidate.is_absolute():
        return str(candidate) if candidate.is_file() else ""
    if "/" in icon or "\\" in icon or icon in (".", ".."):
        return ""
    home = Path.home()
    roots = (
        Path("/usr/share/icons/Papirus/48x48/apps"),
        Path("/usr/share/icons/Papirus-Dark/48x48/apps"),
        Path("/usr/share/icons/hicolor/scalable/apps"),
        Path("/usr/share/icons/hicolor/256x256/apps"),
        Path("/usr/share/icons/hicolor/128x128/apps"),
        Path("/usr/share/icons/hicolor/48x48/apps"),
        Path("/usr/share/pixmaps"),
        home / ".local/share/icons/hicolor/scalable/apps",
        home / ".local/share/icons/hicolor/256x256/apps",
        home / ".local/share/icons/hicolor/128x128/apps",
        home / ".local/share/icons/hicolor/48x48/apps",
        home / ".local/share/icons/Papirus/48x48/apps",
        Path("/var/lib/flatpak/exports/share/icons/hicolor/128x128/apps"),
        Path("/var/lib/flatpak/exports/share/icons/hicolor/64x64/apps"),
        Path("/var/lib/flatpak/exports/share/icons/hicolor/scalable/apps"),
        home / ".local/share/flatpak/exports/share/icons/hicolor/128x128/apps",
        home / ".local/share/flatpak/exports/share/icons/hicolor/64x64/apps",
        home / ".local/share/flatpak/exports/share/icons/hicolor/scalable/apps",
    )
    for root in roots:
        for suffix in (".svg", ".png", ".xpm"):
            path = root / f"{icon}{suffix}"
            if path.is_file():
                return str(path)
    fallback = Path("/usr/share/icons/Papirus/48x48/apps/terminal.svg")
    return str(fallback) if fallback.is_file() else ""

def _read_desktop(path):
    try:
        lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError:
        return None
    section = False
    values = {}
    for raw in lines:
        line = raw.strip()
        if line.startswith("["):
            section = line == "[Desktop Entry]"
            continue
        if not section or not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key] = value
    if values.get("NoDisplay", "").lower() == "true" or values.get("Hidden", "").lower() == "true":
        return None
    name = values.get("Name[pt_BR]") or values.get("Name")
    command = values.get("Exec")
    if not name or not command:
        return None
    return AppData(name, _icon_path(values.get("Icon", "")), command)

def _load_apps():
    apps = []
    seen = set()
    for directory in _application_dirs():
        try:
            entries = sorted(directory.glob("*.desktop"))
        except OSError:
            continue
        for path in entries:
            app = _read_desktop(path)
            if app and app.nome not in seen:
                seen.add(app.nome)
                apps.append(app)
    return sorted(apps, key=lambda app: app.nome.casefold())

def filter_apps(text):
    query = text.casefold()
    usage = utils.read_usage()
    apps = [app for app in _load_apps() if query in app.nome.casefold()]
    apps.sort(key=lambda app: usage.get(app.nome, 0), reverse=True)
    results = [app.as_dict() for app in apps[:15]]
    calculation = utils.calculate(text)
    if calculation is not None:
        results.insert(0, {
            "nome": f"{text.strip()} = {calculation}",
            "icone_path": _icon_path("accessories-calculator"),
            "exec": f"@copy:{calculation}",
        })
    elif not results and text.strip():
        results.append({"nome": text, "icone_path": _icon_path("kitty"), "exec": f"@term:{text}"})
    return results

def _terminal():
    configured = os.environ.get("TERMINAL", "").strip()
    if configured:
        try:
            parts = shlex.split(configured)
        except ValueError:
            parts = []
        if parts and shutil.which(parts[0]):
            return parts
    for name in ("kitty", "alacritty", "foot", "wezterm", "konsole", "gnome-terminal", "kgx", "xterm"):
        path = shutil.which(name)
        if path:
            return [path]
    return []

def _open_terminal(command):
    terminal = _terminal()
    if not terminal:
        return
    shell = os.environ.get("SHELL") or "/bin/sh"
    shell_command = f"{command}; exec {shlex.quote(shell)}"
    name = Path(terminal[0]).name
    if name in ("gnome-terminal", "kgx"):
        args = terminal + ["--", "sh", "-lc", shell_command]
    elif name == "wezterm":
        args = terminal + ["start", "--", "sh", "-lc", shell_command]
    else:
        args = terminal + ["-e", "sh", "-lc", shell_command]
    try:
        subprocess.Popen(args, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
    except OSError:
        return

def execute(exec_command, app_name=""):
    if exec_command.startswith("@term:"):
        _open_terminal(exec_command[6:])
        return
    if exec_command.startswith("@copy:"):
        try:
            subprocess.run(["wl-copy"], input=exec_command[6:].encode(), check=False, timeout=5)
        except (OSError, subprocess.TimeoutExpired):
            pass
        return
    try:
        args = shlex.split(exec_command)
    except ValueError:
        return
    cleaned = []
    field_codes = re.compile(r"%(?:[fFuUdDnNickvm])")
    for arg in args:
        if arg in ("%f", "%F", "%u", "%U", "%i", "%d", "%D", "%n", "%N", "%v", "%m"):
            continue
        arg = field_codes.sub("", arg.replace("%c", app_name))
        if arg:
            cleaned.append(arg)
    if not cleaned or (not shutil.which(cleaned[0]) and not Path(cleaned[0]).is_file()):
        return
    try:
        subprocess.Popen(cleaned, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
    except OSError:
        return
