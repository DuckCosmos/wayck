import os
import re
import subprocess
import tempfile
from pathlib import Path

_ID_PATTERN = re.compile(r"^[0-9]+$")
_CACHE_PREFIX = f"wayck_clip_{os.getuid()}_"

def _valid_id(value):
    return isinstance(value, str) and bool(_ID_PATTERN.fullmatch(value))

def _run(args, **kwargs):
    return subprocess.run(args, check=True, timeout=15, **kwargs)

def _image_path(item_id):
    return Path(tempfile.gettempdir()) / f"{_CACHE_PREFIX}{item_id}.png"

def _decode_image(item_id):
    path = _image_path(item_id)
    if path.is_file():
        return str(path)
    descriptor = None
    temporary = None
    try:
        descriptor, temporary = tempfile.mkstemp(prefix=_CACHE_PREFIX, suffix=".png", dir=tempfile.gettempdir())
        os.fchmod(descriptor, 0o600)
        with os.fdopen(descriptor, "wb") as output:
            descriptor = None
            _run(["cliphist", "decode", item_id], stdout=output, stderr=subprocess.DEVNULL)
        os.replace(temporary, path)
        os.chmod(path, 0o600)
        return str(path)
    except (OSError, subprocess.SubprocessError):
        if descriptor is not None:
            os.close(descriptor)
        if temporary:
            Path(temporary).unlink(missing_ok=True)
        return None

def list_items(term=""):
    try:
        result = _run(["cliphist", "list"], capture_output=True, text=True, errors="replace")
    except (OSError, subprocess.SubprocessError):
        return []
    query = term.casefold()
    items = []
    for line in result.stdout.splitlines():
        if "\t" not in line:
            continue
        item_id, content = line.split("\t", 1)
        if not _valid_id(item_id) or (query and query not in content.casefold()):
            continue
        is_image = content.startswith("[[ binary data") and "png" in content.casefold()
        path = _decode_image(item_id) if is_image else None
        if is_image and path is None:
            continue
        items.append({
            "id": item_id,
            "content": content if is_image else content.replace("\n", " "),
            "is_image": is_image,
            "path": path,
        })
        if len(items) >= 50:
            break
    return items

def copy_item(item_id):
    if not _valid_id(item_id):
        return
    source = destination = None
    try:
        source = subprocess.Popen(["cliphist", "decode", item_id], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
        destination = subprocess.Popen(["wl-copy"], stdin=source.stdout, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        source.stdout.close()
        destination.wait(timeout=15)
        if destination.returncode:
            source.terminate()
        source.wait(timeout=5)
    except (OSError, subprocess.SubprocessError):
        for process in (destination, source):
            if process and process.poll() is None:
                process.kill()
                process.wait()

def delete_item(item_id):
    if not _valid_id(item_id):
        return
    try:
        _run(["cliphist", "delete"], input=f"{item_id}\n", text=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except (OSError, subprocess.SubprocessError):
        return

def clear():
    _run(["wl-copy", "--clear"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    _run(["cliphist", "wipe"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    for path in Path(tempfile.gettempdir()).glob(f"{_CACHE_PREFIX}*.png"):
        try:
            if path.is_file() and path.stat().st_uid == os.getuid():
                path.unlink()
        except OSError:
            continue
