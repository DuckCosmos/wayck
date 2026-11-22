using System.Text.Json.Serialization;

namespace Wayck.Backend;

internal sealed class VersionInfo
{
    [JsonPropertyName("local")] public string Local { get; set; } = "";
    [JsonPropertyName("remote")] public string Remote { get; set; } = "";
    [JsonPropertyName("available")] public bool Available { get; set; }
}

internal static class Update
{
    private const string VersionUrl = "https://raw.githubusercontent.com/DuckCosmos/wayck/main/version.txt";
    private static string LocalVersion()
    {
        var candidates = new List<string>();
        var exe = Environment.ProcessPath;
        if (exe is not null)
        {
            var parent = Path.GetDirectoryName(exe);
            if (parent is not null)
            {
                candidates.Add(Path.Combine(parent, "version.txt"));
                var root = parent;
                for (int i = 0; i < 3; i++) root = Path.GetDirectoryName(root) ?? root;
                candidates.Add(Path.Combine(root, "version.txt"));
            }
        }
        candidates.Add(Path.Combine(Environment.CurrentDirectory, "version.txt"));
        foreach (var path in candidates)
            try { return File.ReadAllText(path).Trim(); } catch { }
        return "";
    }
    private static string RemoteVersion()
    {
        using var client = new HttpClient { Timeout = TimeSpan.FromSeconds(8) };
        client.DefaultRequestHeaders.UserAgent.ParseAdd("Wayck-Updater/1.0");
        var text = client.GetStringAsync(VersionUrl).GetAwaiter().GetResult();
        return new string(text.EnumerateRunes().Take(256).SelectMany(r => r.ToString()).ToArray()).Trim();
    }
    public static VersionInfo CheckInfo()
    {
        var local = LocalVersion(); var remote = RemoteVersion();
        return new VersionInfo { Local = local, Remote = remote, Available = local.Length > 0 && remote.Length > 0 && remote != local };
    }
    public static bool Check() => CheckInfo().Available;
}