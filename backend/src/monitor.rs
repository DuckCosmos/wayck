use serde_json::{json, Value};
use std::fs;
use std::process::Command;
use std::thread;
use std::time::{Duration, Instant};

fn rounded(value: f64) -> f64 { (value * 10.0).round() / 10.0 }

fn cpu_counters() -> Option<(u64, u64)> {
    let data = fs::read_to_string("/proc/stat").ok()?;
    let mut values = data.lines().next()?.split_whitespace().skip(1).take(8).map(str::parse::<u64>);
    let mut numbers = Vec::new();
    for value in values.by_ref() { numbers.push(value.ok()?); }
    if numbers.len() < 8 { return None; }
    Some((numbers.iter().sum(), numbers[3] + numbers[4]))
}

fn memory_usage() -> (f64, f64, f64) {
    let Ok(data) = fs::read_to_string("/proc/meminfo") else { return (0.0, 0.0, 0.0) };
    let mut total = 0.0;
    let mut available = 0.0;
    for line in data.lines() {
        let Some((key, value)) = line.split_once(':') else { continue };
        let amount = value.split_whitespace().next().and_then(|v| v.parse::<f64>().ok()).unwrap_or(0.0);
        match key { "MemTotal" => total = amount, "MemAvailable" => available = amount, _ => {} }
    }
    if total <= 0.0 { return (0.0, 0.0, 0.0); }
    let used = (total - available).max(0.0);
    (rounded(used / total * 100.0), rounded(used / 1024.0), rounded(total / 1024.0))
}

fn disk_usage() -> (f64, f64, f64) {
    let Ok(output) = Command::new("df").args(["-B1", "--output=size,used,avail", "/"]).output() else { return (0.0, 0.0, 0.0) };
    let text = String::from_utf8_lossy(&output.stdout);
    let Some(line) = text.lines().nth(1) else { return (0.0, 0.0, 0.0) };
    let values: Vec<f64> = line.split_whitespace().filter_map(|v| v.parse().ok()).collect();
    if values.len() < 3 || values[0] <= 0.0 { return (0.0, 0.0, 0.0); }
    let total = values[0];
    let used = values[1];
    (rounded(used / total * 100.0), rounded(used / 1_073_741_824.0), rounded(total / 1_073_741_824.0))
}

fn network_counters() -> (u64, u64) {
    let Ok(data) = fs::read_to_string("/proc/net/dev") else { return (0, 0) };
    let mut received = 0u64;
    let mut sent = 0u64;
    for line in data.lines().skip(2) {
        let Some((interface, raw)) = line.split_once(':') else { continue };
        if interface.trim() == "lo" { continue; }
        let fields: Vec<_> = raw.split_whitespace().collect();
        if fields.len() < 9 { continue; }
        received = received.saturating_add(fields[0].parse().unwrap_or(0));
        sent = sent.saturating_add(fields[8].parse().unwrap_or(0));
    }
    (received, sent)
}

fn cpu_temperature() -> Option<f64> {
    let entries = fs::read_dir("/sys/class/hwmon").ok()?;
    let mut temperatures: Vec<f64> = Vec::new();
    for entry in entries.flatten() {
        let path = entry.path();
        let chip = fs::read_to_string(path.join("name")).unwrap_or_default().trim().to_lowercase();
        let cpu_chip = ["coretemp", "k10temp", "zenpower"].iter().any(|v| chip.contains(v));
        let Ok(sensors) = fs::read_dir(&path) else { continue };
        for sensor in sensors.flatten() {
            let name = sensor.file_name().to_string_lossy().to_string();
            if !name.starts_with("temp") || !name.ends_with("_input") { continue; }
            let stem = name.trim_end_matches("_input");
            let label = fs::read_to_string(path.join(format!("{stem}_label"))).unwrap_or_default().trim().to_lowercase();
            let cpu_label = ["cpu", "package", "tctl", "tdie", "core"].iter().any(|v| label.contains(v));
            let raw = fs::read_to_string(sensor.path()).ok().and_then(|v| v.trim().parse::<f64>().ok()).map(|v| v / 1000.0);
            if let Some(value) = raw {
                if (cpu_chip || cpu_label) && (-20.0..=150.0).contains(&value) { temperatures.push(value); }
            }
        }
    }
    temperatures.into_iter().reduce(f64::max).map(rounded)
}

fn gpu_data() -> (bool, Option<f64>, Option<f64>, Option<f64>, Option<f64>, Option<f64>) {
    let output = Command::new("nvidia-smi")
        .args(["--query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total", "--format=csv,noheader,nounits"])
        .output();
    let Ok(output) = output else { return (false, None, None, None, None, None) };
    if !output.status.success() { return (false, None, None, None, None, None); }
    let line = String::from_utf8_lossy(&output.stdout);
    let Some(line) = line.lines().next() else { return (false, None, None, None, None, None) };
    let values: Vec<Option<f64>> = line.split(',').map(|v| {
        let value = v.trim();
        if value.eq_ignore_ascii_case("N/A") { None } else { value.parse().ok() }
    }).collect();
    if values.len() < 4 { return (false, None, None, None, None, None); }
    let (usage, temp, used, total) = (values[0], values[1], values[2], values[3]);
    let vram = match (used, total) { (Some(u), Some(t)) if t > 0.0 => Some(rounded(u / t * 100.0)), _ => None };
    (true, usage.map(|v| rounded(v.clamp(0.0, 100.0))), temp.map(rounded), vram, used.map(rounded), total.map(rounded))
}

pub fn run() {
    let mut previous_cpu: Option<(u64, u64)> = None;
    let mut previous_network: Option<(u64, u64, Instant)> = None;
    loop {
        let started = Instant::now();
        let current_cpu = cpu_counters();
        let cpu = match (previous_cpu, current_cpu) {
            (Some((old_total, old_idle)), Some((total, idle))) => {
                let delta = total.saturating_sub(old_total) as f64;
                let idle_delta = idle.saturating_sub(old_idle) as f64;
                if delta > 0.0 { rounded(((1.0 - idle_delta.min(delta) / delta) * 100.0).clamp(0.0, 100.0)) } else { 0.0 }
            }
            _ => 0.0,
        };
        if current_cpu.is_some() { previous_cpu = current_cpu; }
        let (ram, ram_used, ram_total) = memory_usage();
        let (disk, disk_used, disk_total) = disk_usage();
        let (received, sent) = network_counters();
        let (down, up) = match previous_network {
            Some((old_received, old_sent, old_time)) => {
                let elapsed = old_time.elapsed().as_secs_f64().max(0.001);
                (rounded(received.saturating_sub(old_received) as f64 / 1024.0 / elapsed), rounded(sent.saturating_sub(old_sent) as f64 / 1024.0 / elapsed))
            }
            None => (0.0, 0.0),
        };
        previous_network = Some((received, sent, Instant::now()));
        let (gpu_available, gpu, gpu_temp, vram_percent, vram_used, vram_total) = gpu_data();
        let data: Value = json!({
            "cpu_percent": cpu, "ram_percent": ram, "ram_used_mb": ram_used, "ram_total_mb": ram_total,
            "disk_percent": disk, "disk_used_gib": disk_used, "disk_total_gib": disk_total,
            "gpu_available": gpu_available, "gpu_percent": gpu, "gpu_temp_c": gpu_temp,
            "gpu_vram_percent": vram_percent, "gpu_vram_used_mb": vram_used, "gpu_vram_total_mb": vram_total,
            "network_down_kib_s": down, "network_up_kib_s": up, "temperature_c": cpu_temperature()
        });
        println!("{data}");
        use std::io::Write;
        if std::io::stdout().flush().is_err() { return; }
        thread::sleep(Duration::from_secs_f64((1.0 - started.elapsed().as_secs_f64()).max(0.0)));
    }
}
