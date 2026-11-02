use serde::Serialize;
use std::{
    fs,
    io::{self, Write},
    process::Command,
    thread,
    time::{Duration, Instant},
};

#[derive(Serialize)]
struct Metrics {
    cpu_percent: f64,
    ram_percent: f64,
    ram_used_mb: f64,
    ram_total_mb: f64,
    disk_percent: f64,
    disk_used_gib: f64,
    disk_total_gib: f64,
    gpu_available: bool,
    gpu_percent: Option<f64>,
    gpu_temp_c: Option<f64>,
    gpu_vram_percent: Option<f64>,
    gpu_vram_used_mb: Option<f64>,
    gpu_vram_total_mb: Option<f64>,
    network_down_kib_s: f64,
    network_up_kib_s: f64,
    temperature_c: Option<f64>,
}

fn round1(v: f64) -> f64 {
    (v * 10.0).round() / 10.0
}

fn cpu_counters() -> Option<(u64, u64)> {
    let contents = fs::read_to_string("/proc/stat").ok()?;
    let line = contents.lines().find(|s| s.starts_with("cpu "))?;

    let values: Vec<u64> = line
        .split_whitespace()
        .skip(1)
        .filter_map(|s| s.parse().ok())
        .collect();

    if values.len() < 8 {
        return None;
    }

    let total = values.iter().take(8).sum();
    let idle = values[3] + values[4];

    Some((total, idle))
}

fn cpu_usage(previous: &mut Option<(u64, u64)>) -> f64 {
    let Some(now) = cpu_counters() else {
        return 0.0;
    };

    let result = if let Some((old_total, old_idle)) = *previous {
        let total = now.0.saturating_sub(old_total);
        let idle = now.1.saturating_sub(old_idle).min(total);

        if total == 0 {
            0.0
        } else {
            (1.0 - idle as f64 / total as f64) * 100.0
        }
    } else {
        0.0
    };

    *previous = Some(now);
    round1(result.clamp(0.0, 100.0))
}

fn memory_usage() -> (f64, f64, f64) {
    let Ok(contents) = fs::read_to_string("/proc/meminfo") else {
        return (0.0, 0.0, 0.0);
    };

    let mut total: f64 = 0.0;
    let mut available: f64 = 0.0;

    for line in contents.lines() {
        let mut parts = line.split_whitespace();

        match parts.next() {
            Some("MemTotal:") => {
                total = parts.next().and_then(|v| v.parse().ok()).unwrap_or(0.0);
            }
            Some("MemAvailable:") => {
                available = parts.next().and_then(|v| v.parse().ok()).unwrap_or(0.0);
            }
            _ => {}
        }
    }

    if total <= 0.0 {
        return (0.0, 0.0, 0.0);
    }

    let used = (total - available).max(0.0);

    (
        round1(used / total * 100.0),
        round1(used / 1024.0),
        round1(total / 1024.0),
    )
}

fn disk_usage() -> (f64, f64, f64) {
    let output = Command::new("df")
        .args(["-Pk", "/"])
        .output();

    let Ok(output) = output else {
        return (0.0, 0.0, 0.0);
    };

    if !output.status.success() {
        return (0.0, 0.0, 0.0);
    }

    let text = String::from_utf8_lossy(&output.stdout);
    let Some(line) = text.lines().nth(1) else {
        return (0.0, 0.0, 0.0);
    };

    let columns: Vec<&str> = line.split_whitespace().collect();

    if columns.len() < 6 {
        return (0.0, 0.0, 0.0);
    }

    let total = columns[1].parse::<f64>().unwrap_or(0.0);
    let used = columns[2].parse::<f64>().unwrap_or(0.0);
    let percent = columns[4]
        .trim_end_matches('%')
        .parse::<f64>()
        .unwrap_or(0.0);

    const KIB_PER_GIB: f64 = 1024.0 * 1024.0;

    (
        round1(percent.clamp(0.0, 100.0)),
        round1(used / KIB_PER_GIB),
        round1(total / KIB_PER_GIB),
    )
}

fn network_counters() -> (u64, u64) {
    let Ok(contents) = fs::read_to_string("/proc/net/dev") else {
        return (0, 0);
    };

    let mut rx = 0u64;
    let mut tx = 0u64;

    for line in contents.lines().skip(2) {
        let Some((interface, stats)) = line.split_once(':') else {
            continue;
        };

        if interface.trim() == "lo" {
            continue;
        }

        let values: Vec<u64> = stats
            .split_whitespace()
            .filter_map(|v| v.parse().ok())
            .collect();

        if values.len() >= 9 {
            rx = rx.saturating_add(values[0]);
            tx = tx.saturating_add(values[8]);
        }
    }

    (rx, tx)
}

fn network_speed(
    previous: &mut Option<(u64, u64, Instant)>,
) -> (f64, f64) {
    let (rx, tx) = network_counters();
    let now = Instant::now();

    let result = if let Some((old_rx, old_tx, old_time)) = *previous {
        let elapsed = now.duration_since(old_time).as_secs_f64().max(0.001);

        (
            round1(rx.saturating_sub(old_rx) as f64 / 1024.0 / elapsed),
            round1(tx.saturating_sub(old_tx) as f64 / 1024.0 / elapsed),
        )
    } else {
        (0.0, 0.0)
    };

    *previous = Some((rx, tx, now));
    result
}

fn read_temp(path: &std::path::Path) -> Option<f64> {
    let raw = fs::read_to_string(path).ok()?;
    let value = raw.trim().parse::<f64>().ok()? / 1000.0;

    if !(-20.0..150.0).contains(&value) {
        return None;
    }

    Some(round1(value))
}

fn cpu_temperature() -> Option<f64> {
    let mut values = Vec::new();

    if let Ok(devices) = fs::read_dir("/sys/class/hwmon") {
        for device in devices.flatten() {
            let path = device.path();

            let chip = fs::read_to_string(path.join("name"))
                .unwrap_or_default()
                .trim()
                .to_lowercase();

            let cpu_chip = ["coretemp", "k10temp", "zenpower"]
                .iter()
                .any(|name| chip.contains(name));

            let Ok(entries) = fs::read_dir(&path) else {
                continue;
            };

            for entry in entries.flatten() {
                let filename = entry.file_name().to_string_lossy().to_string();

                let Some(stem) = filename.strip_suffix("_input") else {
                    continue;
                };

                if !stem.starts_with("temp") {
                    continue;
                }

                let label = fs::read_to_string(
                    path.join(format!("{stem}_label"))
                )
                .unwrap_or_default()
                .to_lowercase();

                let cpu_label = [
                    "cpu", "package", "tctl", "tdie", "core",
                ]
                .iter()
                .any(|name| label.contains(name));

                if cpu_chip || cpu_label {
                    if let Some(v) = read_temp(&entry.path()) {
                        values.push(v);
                    }
                }
            }
        }
    }

    if let Some(value) = values.into_iter().reduce(f64::max) {
        return Some(value);
    }

    None
}

fn gpu_data() -> (
    bool,
    Option<f64>,
    Option<f64>,
    Option<f64>,
    Option<f64>,
    Option<f64>,
) {
    let output = Command::new("nvidia-smi")
        .args([
            "--query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total",
            "--format=csv,noheader,nounits",
        ])
        .output();

    let Ok(output) = output else {
        return (false, None, None, None, None, None);
    };

    if !output.status.success() {
        return (false, None, None, None, None, None);
    }

    let text = String::from_utf8_lossy(&output.stdout);
    let Some(line) = text.lines().next() else {
        return (false, None, None, None, None, None);
    };

    let columns: Vec<&str> = line.split(',').map(str::trim).collect();

    if columns.len() < 4 {
        return (false, None, None, None, None, None);
    }

    let parse = |v: &str| {
        if v.eq_ignore_ascii_case("N/A") {
            None
        } else {
            v.parse::<f64>().ok()
        }
    };

    let usage = parse(columns[0]).map(|v| round1(v.clamp(0.0, 100.0)));
    let temp = parse(columns[1]).map(round1);
    let used = parse(columns[2]).map(round1);
    let total = parse(columns[3]).map(round1);

    let vram_percent = match (used, total) {
        (Some(u), Some(t)) if t > 0.0 => {
            Some(round1((u / t * 100.0).clamp(0.0, 100.0)))
        }
        _ => None,
    };

    (true, usage, temp, vram_percent, used, total)
}

pub fn run() {
    let mut old_cpu = None;
    let mut old_network = None;

    loop {
        let cpu = cpu_usage(&mut old_cpu);
        let (ram, ram_used, ram_total) = memory_usage();
        let (disk, disk_used, disk_total) = disk_usage();
        let (download, upload) = network_speed(&mut old_network);

        let temperature = cpu_temperature();

        let (
            gpu_available,
            gpu,
            gpu_temperature,
            vram_percent,
            vram_used,
            vram_total,
        ) = gpu_data();

        let metrics = Metrics {
            cpu_percent: cpu,

            ram_percent: ram,
            ram_used_mb: ram_used,
            ram_total_mb: ram_total,

            disk_percent: disk,
            disk_used_gib: disk_used,
            disk_total_gib: disk_total,

            gpu_available,
            gpu_percent: gpu,
            gpu_temp_c: gpu_temperature,
            gpu_vram_percent: vram_percent,
            gpu_vram_used_mb: vram_used,
            gpu_vram_total_mb: vram_total,

            network_down_kib_s: download,
            network_up_kib_s: upload,

            temperature_c: temperature,
        };

        if let Ok(json) = serde_json::to_string(&metrics) {
            println!("{json}");
            let _ = io::stdout().flush();
        }

        thread::sleep(Duration::from_secs(1));
    }
}
