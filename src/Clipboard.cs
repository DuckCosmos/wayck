using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text.Json;

namespace Wayck.Backend;

internal static class Clipboard
{
    [DllImport("libc", EntryPoint = "geteuid")] private static extern uint GetEffectiveUid();
    private static string Prefix => $"wayck_clip_{GetEffectiveUid()}_";
    private static string ImagePath(string id) => Path.Combine(Path.GetTempPath(), Prefix + id + ".png");
    private static bool ValidId(string id) => id.Length > 0 && id.All(char.IsAsciiDigit);

    private static string? DecodeImage(string id)
    {
        var path = ImagePath(id);
        if (File.Exists(path)) return path;
        var temporary = Path.Combine(Path.GetTempPath(), Prefix + Guid.NewGuid().ToString("N") + ".tmp");
        try
        {
            using var proc = new Process();
            proc.StartInfo = new("cliphist") { UseShellExecute = false, RedirectStandardOutput = true, RedirectStandardError = true };
            proc.StartInfo.ArgumentList.Add("decode"); proc.StartInfo.ArgumentList.Add(id);
            proc.Start();
            using (var output = File.Create(temporary)) proc.StandardOutput.BaseStream.CopyTo(output);
            if (!proc.WaitForExit() || proc.ExitCode != 0) { File.Delete(temporary); return null; }
            File.Move(temporary, path, true);
            File.SetUnixFileMode(path, UnixFileMode.UserRead | UnixFileMode.UserWrite);
            return path;
        }
        catch { try { File.Delete(temporary); } catch {} return null; }
    }

    public static List<ClipboardItem> ListItems(string term)
    {
        var items = new List<ClipboardItem>();
        try
        {
            using var process = Process.Start(new ProcessStartInfo("cliphist", "list") { UseShellExecute = false, RedirectStandardOutput = true, RedirectStandardError = true });
            if (process is null) return items;
            var outputText = process.StandardOutput.ReadToEnd();
            process.WaitForExit();
            if (process.ExitCode != 0) return items;
            var query = term.ToLowerInvariant();
            foreach (var line in outputText.Split('\n'))
            {
                var split = line.Split('\t', 2); if (split.Length != 2) continue;
                var id = split[0]; var content = split[1];
                if (!ValidId(id) || (query.Length > 0 && !content.ToLowerInvariant().Contains(query))) continue;
                var isImage = content.StartsWith("[[ binary data", StringComparison.Ordinal) && content.Contains("png", StringComparison.OrdinalIgnoreCase);
                var path = isImage ? DecodeImage(id) : null;
                if (isImage && path is null) continue;
                items.Add(new ClipboardItem(id, isImage ? content : content.Replace('\n', ' '), isImage, path));
                if (items.Count >= 50) break;
            }
        } catch { }
        return items;
    }

    public static void CopyItem(string id)
    {
        if (!ValidId(id)) return;
        try
        {
            var source = Process.Start(new ProcessStartInfo("cliphist", $"decode {id}") { UseShellExecute = false, RedirectStandardOutput = true, RedirectStandardError = true });
            if (source is null) return;
            var target = Process.Start(new ProcessStartInfo("wl-copy") { UseShellExecute = false, RedirectStandardInput = true, RedirectStandardOutput = true, RedirectStandardError = true });
            if (target is null) { source.Kill(); return; }
            source.StandardOutput.BaseStream.CopyTo(target.StandardInput.BaseStream);
            target.StandardInput.Close();
            target.WaitForExit(); source.WaitForExit();
        } catch { }
    }

    public static void DeleteItem(string id)
    {
        if (!ValidId(id)) return;
        try
        {
            using var process = Process.Start(new ProcessStartInfo("cliphist", "delete") { UseShellExecute = false, RedirectStandardInput = true, RedirectStandardOutput = true, RedirectStandardError = true });
            if (process is null) return;
            process.StandardInput.WriteLine(id); process.StandardInput.Close(); process.WaitForExit();
        } catch { }
    }

    public static void Clear()
    {
        var wl = Process.Start(new ProcessStartInfo("wl-copy", "--clear") { UseShellExecute = false, RedirectStandardOutput = true, RedirectStandardError = true });
        wl?.WaitForExit();
        var clip = Process.Start(new ProcessStartInfo("cliphist", "wipe") { UseShellExecute = false, RedirectStandardOutput = true, RedirectStandardError = true });
        clip?.WaitForExit();
        foreach (var file in Directory.EnumerateFiles(Path.GetTempPath(), Prefix + "*.png"))
            try { File.Delete(file); } catch { }
    }
}