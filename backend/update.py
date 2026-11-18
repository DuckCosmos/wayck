import urllib.request
from pathlib import Path

VERSION_URL = "https://raw.githubusercontent.com/DuckCosmos/wayck/main/version.txt"

def local_version():
    path = Path(__file__).resolve().parent.parent / "version.txt"
    try:
        return path.read_text(encoding="utf-8").strip()
    except OSError:
        return ""

def remote_version():
    request = urllib.request.Request(VERSION_URL, headers={"User-Agent": "Wayck-Updater/1.0"})
    with urllib.request.urlopen(request, timeout=8) as response:
        return response.read(256).decode("utf-8", errors="replace").strip()

def check_info():
    local = local_version()
    remote = remote_version()
    return local, remote, bool(local and remote and remote != local)

def check():
    return check_info()[2]
