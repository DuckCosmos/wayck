using System.Text.RegularExpressions;

namespace Wayck.Backend;

internal sealed record AppData(string nome, string icone_path, string exec);

internal static class Launcher
{
    private static readonly string Home = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
    private static IEnumerable<string> ApplicationDirs => new[]
    {
        "/usr/share/applications", "/usr/local/share/applications", "/var/lib/flatpak/exports/share/applications",
        Path.Combine(Home, ".local/share/applications"), Path.Combine(Home, ".local/share/flatpak/exports/share/applications")
    };

    private static string IconPath(string icon)
    {
        if (string.IsNullOrEmpty(icon)) return "";
        icon = icon.Replace("~", Home);
        if (Path.IsPathRooted(icon)) return File.Exists(icon) ? icon : "";
        if (icon.Contains('/') || icon.Contains('\\') || icon is "." or "..") return "";
        var roots = new[]
        {
            "/usr/share/icons/Papirus/48x48/apps", "/usr/share/icons/Papirus-Dark/48x48/apps",
            "/usr/share/icons/hicolor/scalable/apps", "/usr/share/icons/hicolor/256x256/apps",
            "/usr/share/icons/hicolor/128x128/apps", "/usr/share/icons/hicolor/48x48/apps", "/usr/share/pixmaps",
            Path.Combine(Home, ".local/share/icons/hicolor/scalable/apps"), Path.Combine(Home, ".local/share/icons/hicolor/256x256/apps"),
            Path.Combine(Home, ".local/share/icons/hicolor/128x128/apps"), Path.Combine(Home, ".local/share/icons/hicolor/48x48/apps"),
            Path.Combine(Home, ".local/share/icons/Papirus/48x48/apps"),
            "/var/lib/flatpak/exports/share/icons/hicolor/128x128/apps", "/var/lib/flatpak/exports/share/icons/hicolor/64x64/apps",
            "/var/lib/flatpak/exports/share/icons/hicolor/scalable/apps",
            Path.Combine(Home, ".local/share/flatpak/exports/share/icons/hicolor/128x128/apps"),
            Path.Combine(Home, ".local/share/flatpak/exports/share/icons/hicolor/64x64/apps"),
            Path.Combine(Home, ".local/share/flatpak/exports/share/icons/hicolor/scalable/apps")
        };
        foreach (var root in roots)
            foreach (var ext in new[] { "svg", "png", "xpm" })
            {
                var path = Path.Combine(root, icon + "." + ext);
                if (File.Exists(path)) return path;
            }
        var fallback = "/usr/share/icons/Papirus/48x48/apps/terminal.svg";
        return File.Exists(fallback) ? fallback : "";
    }

    private static AppData? ReadDesktop(string path)
    {
        string text;
        try { text = File.ReadAllText(path); } catch { return null; }
        var inDesktop = false; string name = "", icon = "", exec = "", pt = "";
        foreach (var raw in text.Split('\n'))
        {
            var line = raw.Trim();
            if (line.StartsWith('[')) { inDesktop = line == "[Desktop Entry]"; continue; }
            if (!inDesktop || line.Length == 0 || line.StartsWith('#')) continue;
            var split = line.Split('=', 2); if (split.Length != 2) continue;
            var key = split[0]; var value = split[1];
            if ((key is "NoDisplay" or "Hidden") && value.Equals("true", StringComparison.OrdinalIgnoreCase)) return null;
            switch (key) { case "Name[pt_BR]": pt = value; break; case "Name": name = value; break; case "Icon": icon = value; break; case "Exec": exec = value; break; }
        }
        name = pt.Length > 0 ? pt : name;
        return string.IsNullOrEmpty(name) || string.IsNullOrEmpty(exec) ? null : new AppData(name, IconPath(icon), exec);
    }

    private static List<AppData> LoadApps()
    {
        var apps = new List<AppData>(); var seen = new HashSet<string>();
        foreach (var dir in ApplicationDirs)
        {
            try
            {
                var paths = Directory.EnumerateFiles(dir, "*.desktop").OrderBy(p => p, StringComparer.Ordinal);
                foreach (var path in paths)
                {
                    var app = ReadDesktop(path);
                    if (app is not null && seen.Add(app.nome)) apps.Add(app);
                }
            } catch { }
        }
        return apps.OrderBy(a => a.nome.ToLowerInvariant(), StringComparer.Ordinal).ToList();
    }

    public static List<AppData> FilterApps(string text)
    {
        var query = text.ToLowerInvariant();
        var usage = Utils.ReadUsage();
        var apps = LoadApps().Where(a => a.nome.ToLowerInvariant().Contains(query))
            .OrderByDescending(a => usage.GetValueOrDefault(a.nome)).Take(15).ToList();
        var calculation = Utils.Calculate(text);
        if (calculation is not null)
            apps.Insert(0, new AppData($"{text.Trim()} = {calculation}", IconPath("accessories-calculator"), $"@copy:{calculation}"));
        else if (apps.Count == 0 && !string.IsNullOrWhiteSpace(text))
            apps.Add(new AppData(text, IconPath("kitty"), $"@term:{text}"));
        return apps;
    }

    private static bool IsExecutable(string path) => File.Exists(path) && (File.GetUnixFileMode(path) & (UnixFileMode.UserExecute | UnixFileMode.GroupExecute | UnixFileMode.OtherExecute)) != 0;
    private static string? Which(string program)
    {
        if (program.Contains('/')) return IsExecutable(program) ? program : null;
        foreach (var dir in (Environment.GetEnvironmentVariable("PATH") ?? "").Split(Path.PathSeparator))
        {
            var path = Path.Combine(dir, program);
            if (IsExecutable(path)) return path;
        }
        return null;
    }
    private static List<string>? SplitCommand(string input)
    {
        var result = new List<string>(); var current = new System.Text.StringBuilder(); char quote = '\0'; bool escape = false;
        foreach (char c in input)
        {
            if (escape) { current.Append(c); escape = false; continue; }
            if (quote != '\'' && c == '\\') { escape = true; continue; }
            if (quote == '\0' && (c == '\'' || c == '"')) { quote = c; continue; }
            if (quote != '\0' && c == quote) { quote = '\0'; continue; }
            if (quote == '\0' && char.IsWhiteSpace(c)) { if (current.Length > 0) { result.Add(current.ToString()); current.Clear(); } continue; }
            current.Append(c);
        }
        if (escape || quote != '\0') return null;
        if (current.Length > 0) result.Add(current.ToString());
        return result;
    }
    private static List<string> Terminal()
    {
        var configured = Environment.GetEnvironmentVariable("TERMINAL");
        if (!string.IsNullOrEmpty(configured))
        {
            var parts = SplitCommand(configured);
            if (parts?.Count > 0 && Which(parts[0]) is not null) return parts;
        }
        foreach (var name in new[] { "kitty", "alacritty", "foot", "wezterm", "konsole", "gnome-terminal", "kgx", "xterm" })
            if (Which(name) is { } path) return new() { path };
        return new();
    }
    private static void OpenTerminal(string command)
    {
        var term = Terminal(); if (term.Count == 0) return;
        var shell = Environment.GetEnvironmentVariable("SHELL") ?? "/bin/sh";
        var quote = "'" + shell.Replace("'", "'\\''") + "'";
        var shellCommand = $"{command}; exec {quote}";
        var name = Path.GetFileName(term[0]);
        if (name is "gnome-terminal" or "kgx") term.AddRange(new[] { "--", "sh", "-lc", shellCommand });
        else if (name == "wezterm") term.AddRange(new[] { "start", "--", "sh", "-lc", shellCommand });
        else term.AddRange(new[] { "-e", "sh", "-lc", shellCommand });
        StartDetached(term);
    }
    private static void StartDetached(IReadOnlyList<string> args)
    {
        try
        {
            var info = new System.Diagnostics.ProcessStartInfo(args[0]) { UseShellExecute = false, RedirectStandardInput = true, RedirectStandardOutput = true, RedirectStandardError = true };
            foreach (var arg in args.Skip(1)) info.ArgumentList.Add(arg);
            var process = System.Diagnostics.Process.Start(info);
            if (process is not null) { process.StandardInput.Close(); process.Dispose(); }
        } catch { }
    }
    public static void Execute(string execCommand, string appName)
    {
        if (execCommand.StartsWith("@term:")) { OpenTerminal(execCommand[5..]); return; }
        if (execCommand.StartsWith("@copy:"))
        {
            try { using var proc = new System.Diagnostics.Process(); proc.StartInfo = new("/usr/bin/wl-copy") { RedirectStandardInput = true, UseShellExecute = false }; proc.Start(); proc.StandardInput.Write(execCommand[6..]); proc.StandardInput.Close(); proc.WaitForExit(); } catch { }
            return;
        }
        var parts = SplitCommand(execCommand); if (parts is null) return;
        var fieldCodes = new Regex("%(?:[fFuUdDnNickvm])");
        var cleaned = new List<string>();
        foreach (var arg in parts)
        {
            if (new[] { "%f", "%F", "%u", "%U", "%i", "%d", "%D", "%n", "%N", "%v", "%m" }.Contains(arg)) continue;
            var replaced = fieldCodes.Replace(arg.Replace("%c", appName), "");
            if (replaced.Length > 0) cleaned.Add(replaced);
        }
        if (cleaned.Count == 0 || Which(cleaned[0]) is null) return;
        StartDetached(cleaned);
    }
}