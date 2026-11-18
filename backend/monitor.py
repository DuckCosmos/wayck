import json
import shutil
import subprocess
import sys
import time
from pathlib import Path

def _round(value):
    return round(float(value), 1)

def _cpu_counters():
    try:
        values = [int(value) for value in Path("/proc/stat").read_text().splitlines()[0].split()[1:9]]
        if len(values) < 8:
            return None
        return sum(values), values[3] + values[4]
    except (OSError, ValueError, IndexError):
        return None

def _cpu_usage(previous):
    current = _cpu_counters()
    if current is None:
        return 0.0, previous
    if previous is None:
        return 0.0, current
    total = max(0, current[0] - previous[0])
    idle = min(total, max(0, current[1] - previous[1]))
    value = 0.0 if total == 0 else (1.0 - idle / total) * 100
    return _round(max(0.0, min(100.0, value))), current

def _memory_usage():
    values = {}
    try:
        for line in Path("/proc/meminfo").read_text().splitlines():
            key, raw = line.split(":", 1)
            if key in ("MemTotal", "MemAvailable"):
                values[key] = float(raw.split()[0])
    except (OSError, ValueError, IndexError):
        return 0.0, 0.0, 0.0
    total = values.get("MemTotal", 0.0)
    available = values.get("MemAvailable", 0.0)
    if total <= 0:
        return 0.0, 0.0, 0.0
    used = max(0.0, total - available)
    return _round(used / total * 100), _round(used / 1024), _round(total / 1024)

def _disk_usage():
    try:
        usage = shutil.disk_usage("/")
    except OSError:
        return 0.0, 0.0, 0.0
    if usage.total <= 0:
        return 0.0, 0.0, 0.0
    used = usage.total - usage.free
    return _round(used / usage.total * 100), _round(used / (1024 ** 3)), _round(usage.total / (1024 ** 3))

def _network_counters():
    received = sent = 0
    try:
        lines = Path("/proc/net/dev").read_text().splitlines()[2:]
    except OSError:
        return 0, 0
    for line in lines:
        if ":" not in line:
            continue
        interface, raw = line.split(":", 1)
        if interface.strip() == "lo":
            continue
        fields = raw.split()
        if len(fields) < 9:
            continue
        try:
            received += int(fields[0])
            sent += int(fields[8])
        except ValueError:
            continue
    return received, sent

def _network_speed(previous):
    received, sent = _network_counters()
    now = time.monotonic()
    if previous is None:
        return (0.0, 0.0), (received, sent, now)
    old_received, old_sent, old_time = previous
    elapsed = max(0.001, now - old_time)
    down = max(0, received - old_received) / 1024 / elapsed
    up = max(0, sent - old_sent) / 1024 / elapsed
    return (_round(down), _round(up)), (received, sent, now)

def _cpu_temperature():
    values = []
    try:
        devices = tuple(Path("/sys/class/hwmon").iterdir())
    except OSError:
        return None
    for device in devices:
        try:
            chip = (device / "name").read_text().strip().lower()
            cpu_chip = any(name in chip for name in ("coretemp", "k10temp", "zenpower"))
            for sensor in device.glob("temp*_input"):
                stem = sensor.name[:-6]
                try:
                    label = (device / f"{stem}_label").read_text().strip().lower()
                    raw = float(sensor.read_text().strip()) / 1000
                except (OSError, ValueError):
                    continue
                cpu_label = any(name in label for name in ("cpu", "package", "tctl", "tdie", "core"))
                if (cpu_chip or cpu_label) and -20 <= raw <= 150:
                    values.append(raw)
        except OSError:
            continue
    return _round(max(values)) if values else None

def _gpu_data():
    command = ["nvidia-smi", "--query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total", "--format=csv,noheader,nounits"]
    try:
        result = subprocess.run(command, capture_output=True, text=True, timeout=2, check=True)
        fields = [value.strip() for value in result.stdout.splitlines()[0].split(",")]
        if len(fields) < 4:
            return False, None, None, None, None, None
        values = [None if value.upper() == "N/A" else float(value) for value in fields[:4]]
        usage, temperature, used, total = values
        vram = _round(used / total * 100) if used is not None and total and total > 0 else None
        return True, _round(max(0, min(100, usage))) if usage is not None else None, _round(temperature) if temperature is not None else None, vram, _round(used) if used is not None else None, _round(total) if total is not None else None
    except (OSError, subprocess.SubprocessError, ValueError, IndexError):
        return False, None, None, None, None, None

def collect(previous_cpu, previous_network):
    cpu, previous_cpu = _cpu_usage(previous_cpu)
    ram, ram_used, ram_total = _memory_usage()
    disk, disk_used, disk_total = _disk_usage()
    (download, upload), previous_network = _network_speed(previous_network)
    gpu_available, gpu, gpu_temperature, vram_percent, vram_used, vram_total = _gpu_data()
    data = {
        "cpu_percent": cpu,
        "ram_percent": ram,
        "ram_used_mb": ram_used,
        "ram_total_mb": ram_total,
        "disk_percent": disk,
        "disk_used_gib": disk_used,
        "disk_total_gib": disk_total,
        "gpu_available": gpu_available,
        "gpu_percent": gpu,
        "gpu_temp_c": gpu_temperature,
        "gpu_vram_percent": vram_percent,
        "gpu_vram_used_mb": vram_used,
        "gpu_vram_total_mb": vram_total,
        "network_down_kib_s": download,
        "network_up_kib_s": upload,
        "temperature_c": _cpu_temperature(),
    }
    return data, previous_cpu, previous_network

def run():
    previous_cpu = None
    previous_network = None
    while True:
        started = time.monotonic()
        try:
            data, previous_cpu, previous_network = collect(previous_cpu, previous_network)
            sys.stdout.write(json.dumps(data, separators=(",", ":")) + "\n")
            sys.stdout.flush()
        except BrokenPipeError:
            return
        except Exception as error:
            print(f"Monitor: {error}", file=sys.stderr, flush=True)
        time.sleep(max(0.0, 1.0 - (time.monotonic() - started)))
