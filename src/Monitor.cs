using System.Diagnostics;
using System.Globalization;
using System.Text.Json;

namespace Wayck.Backend;

internal static class Monitor
{
    private static double Round(double v) => Math.Round(v, 1, MidpointRounding.AwayFromZero);
    private static (ulong total, ulong idle)? CpuCounters()
    {
        try
        {
            var fields = File.ReadLines("/proc/stat").First().Split(' ', StringSplitOptions.RemoveEmptyEntries).Skip(1).Take(8).Select(ulong.Parse).ToArray();
            if (fields.Length < 8) return null;
            return (fields.Aggregate(0UL, (a, b) => a + b), fields[3] + fields[4]);
        } catch { return null; }
    }
    private static (double percent, double used, double total) MemoryUsage()
    {
        try
        {
            double total = 0, available = 0;
            foreach (var line in File.ReadLines("/proc/meminfo"))
            {
                var split = line.Split(':', 2); if (split.Length != 2) continue;
                var amount = double.TryParse(split[1].Trim().Split(' ')[0], CultureInfo.InvariantCulture, out var n) ? n : 0;
                if (split[0] == "MemTotal") total = amount;
                else if (split[0] == "MemAvailable") available = amount;
            }
            if (total <= 0) return (0, 0, 0);
            var used = Math.Max(0, total - available);
            return (Round(used / total * 100), Round(used / 1024), Round(total / 1024));
        } catch { return (0, 0, 0); }
    }
    private static (double percent, double used, double total) DiskUsage()
    {
        try
        {
            using var p = Process.Start(new ProcessStartInfo("df", "-B1 --output=size,used,avail /") { UseShellExecute = false, RedirectStandardOutput = true, RedirectStandardError = true });
            if (p is null) return (0, 0, 0);
            var outputText = p.StandardOutput.ReadToEnd();
            p.WaitForExit();
            if (p.ExitCode != 0) return (0, 0, 0);
            var row = outputText.Split('\n').Skip(1).FirstOrDefault()?.Split(' ', StringSplitOptions.RemoveEmptyEntries) ?? Array.Empty<string>();
            var v = row.Select(s => double.TryParse(s, CultureInfo.InvariantCulture, out var x) ? x : 0).ToArray();
            if (v.Length < 3 || v[0] <= 0) return (0, 0, 0);
            return (Round(v[1] / v[0] * 100), Round(v[1] / 1073741824), Round(v[0] / 1073741824));
        } catch { return (0, 0, 0); }
    }
    private static (ulong recv, ulong sent) NetworkCounters()
    {
        try
        {
            ulong recv = 0, sent = 0;
            foreach (var line in File.ReadLines("/proc/net/dev").Skip(2))
            {
                var split = line.Split(':', 2); if (split.Length != 2 || split[0].Trim() == "lo") continue;
                var fields = split[1].Split(' ', StringSplitOptions.RemoveEmptyEntries); if (fields.Length < 9) continue;
                ulong.TryParse(fields[0], out var r); ulong.TryParse(fields[8], out var s);
                recv = recv > ulong.MaxValue - r ? ulong.MaxValue : recv + r;
                sent = sent > ulong.MaxValue - s ? ulong.MaxValue : sent + s;
            }
            return (recv, sent);
        } catch { return (0, 0); }
    }
    private static double? CpuTemperature()
    {
        try
        {
            var temps = new List<double>();
            foreach (var dir in Directory.GetDirectories("/sys/class/hwmon"))
            {
                var chip = File.Exists(Path.Combine(dir, "name")) ? File.ReadAllText(Path.Combine(dir, "name")).Trim().ToLowerInvariant() : "";
                bool cpuChip = new[] { "coretemp", "k10temp", "zenpower" }.Any(chip.Contains);
                foreach (var sensor in Directory.GetFiles(dir, "temp*_input"))
                {
                    var stem = Path.GetFileName(sensor)[..^6];
                    var labelFile = Path.Combine(dir, stem + "_label");
                    var label = File.Exists(labelFile) ? File.ReadAllText(labelFile).Trim().ToLowerInvariant() : "";
                    bool cpuLabel = new[] { "cpu", "package", "tctl", "tdie", "core" }.Any(label.Contains);
                    if (!double.TryParse(File.ReadAllText(sensor).Trim(), CultureInfo.InvariantCulture, out var raw)) continue;
                    var value = raw / 1000;
                    if ((cpuChip || cpuLabel) && value is >= -20 and <= 150) temps.Add(value);
                }
            }
            return temps.Count == 0 ? null : Round(temps.Max());
        } catch { return null; }
    }
    private static (bool available, double? usage, double? temp, double? vramPercent, double? used, double? total) GpuData()
    {
        try
        {
            using var p = Process.Start(new ProcessStartInfo("nvidia-smi", "--query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total --format=csv,noheader,nounits") { UseShellExecute = false, RedirectStandardOutput = true, RedirectStandardError = true });
            if (p is null) return (false, null, null, null, null, null);
            var outputText = p.StandardOutput.ReadToEnd();
            p.WaitForExit();
            if (p.ExitCode != 0) return (false, null, null, null, null, null);
            var line = outputText.Split('\n').FirstOrDefault(); if (line is null) return (false, null, null, null, null, null);
            var values = line.Split(',').Select(s => s.Trim().Equals("N/A", StringComparison.OrdinalIgnoreCase) ? (double?)null : double.TryParse(s.Trim(), CultureInfo.InvariantCulture, out var v) ? v : null).ToArray();
            if (values.Length < 4) return (false, null, null, null, null, null);
            var (u, t, used, total) = (values[0], values[1], values[2], values[3]);
            var vram = used.HasValue && total is > 0 ? Round(used.Value / total.Value * 100) : null;
            return (true, u.HasValue ? Round(Math.Clamp(u.Value, 0, 100)) : null, t.HasValue ? Round(t.Value) : null, vram, used.HasValue ? Round(used.Value) : null, total.HasValue ? Round(total.Value) : null);
        } catch { return (false, null, null, null, null, null); }
    }
    public static void Run()
    {
        (ulong total, ulong idle)? oldCpu = null; (ulong recv, ulong sent, Stopwatch time)? oldNet = null;
        while (true)
        {
            var timer = Stopwatch.StartNew();
            var current = CpuCounters();
            double cpu = 0;
            if (oldCpu.HasValue && current.HasValue)
            {
                var delta = current.Value.total - oldCpu.Value.total;
                var idle = current.Value.idle - oldCpu.Value.idle;
                if (delta > 0) cpu = Round(Math.Clamp(1 - (double)Math.Min(idle, delta) / delta, 0, 1) * 100);
            }
            if (current.HasValue) oldCpu = current;
            var (ram, ramUsed, ramTotal) = MemoryUsage();
            var (disk, diskUsed, diskTotal) = DiskUsage();
            var net = NetworkCounters();
            double down = 0, up = 0;
            if (oldNet.HasValue)
            {
                var elapsed = oldNet.Value.time.Elapsed.TotalSeconds;
                if (elapsed < .001) elapsed = .001;
                down = Round((net.recv >= oldNet.Value.recv ? net.recv - oldNet.Value.recv : 0) / 1024.0 / elapsed);
                up = Round((net.sent >= oldNet.Value.sent ? net.sent - oldNet.Value.sent : 0) / 1024.0 / elapsed);
            }
            oldNet = (net.recv, net.sent, Stopwatch.StartNew());
            var (gpuAvailable, gpu, gpuTemp, vramPercent, vramUsed, vramTotal) = GpuData();
            var data = new MonitorData(
                cpu_percent = cpu, ram_percent = ram, ram_used_mb = ramUsed, ram_total_mb = ramTotal,
                disk_percent = disk, disk_used_gib = diskUsed, disk_total_gib = diskTotal,
                gpu_available = gpuAvailable, gpu_percent = gpu, gpu_temp_c = gpuTemp,
                gpu_vram_percent = vramPercent, gpu_vram_used_mb = vramUsed, gpu_vram_total_mb = vramTotal,
                down, up, CpuTemperature()
            );
            Console.WriteLine(JsonSerializer.Serialize(data)); Console.Out.Flush();
            var delay = Math.Max(0, 1000 - timer.ElapsedMilliseconds);
            Thread.Sleep((int)delay);
        }
    }
}