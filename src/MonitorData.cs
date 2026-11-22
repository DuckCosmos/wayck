namespace Wayck.Backend;

internal sealed record MonitorData(
    double cpu_percent, double ram_percent, double ram_used_mb, double ram_total_mb,
    double disk_percent, double disk_used_gib, double disk_total_gib,
    bool gpu_available, double? gpu_percent, double? gpu_temp_c,
    double? gpu_vram_percent, double? gpu_vram_used_mb, double? gpu_vram_total_mb,
    double network_down_kib_s, double network_up_kib_s, double? temperature_c);
