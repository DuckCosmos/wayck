using System.Text.Json;

namespace Wayck.Backend;

internal static class Program
{
    static readonly JsonSerializerOptions JsonOptions = new() { PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower };

    static int Main(string[] args)
    {
        try
        {
            if (args.Length == 0) { string? line; while ((line = Console.ReadLine()) != null) Print(Filter(line)); return 0; }
            string A(int i) => args.Length > i ? args[i] : "";
            switch (args[0])
            {
                case "--monitor": Monitor(); break;
                case "--filter": Print(Filter(A(1))); break;
                case "--exec": if (args.Length > 2) { Usage(A(1)); RunApp(A(2), A(1)); } break;
                case "--clipboard-list": Print(ClipboardList(A(1))); break;
                case "--clipboard-copy": ClipboardCopy(A(1)); break;
                case "--clipboard-delete": if (ValidId(A(1))) Start("cliphist", new[]{"delete"}, A(1)+"\n"); break;
                case "--clipboard-clear":
                    Start("wl-copy", new[]{"--clear"}); Start("cliphist", new[]{"wipe"});
                    foreach (var f in Directory.GetFiles(Path.GetTempPath(), Prefix+"*.png")) try { File.Delete(f); } catch {}
                    break;
                case "--check_version": Console.WriteLine(CheckVersion().Available.ToString().ToLowerInvariant()); break;
                case "--version_info": Print(CheckVersion()); break;
            }
            return 0;
        }
        catch (Exception e) { Console.Error.WriteLine("Wayck backend: " + e.Message); return 1; }
    }

    static void Print(object x) => Console.WriteLine(JsonSerializer.Serialize(x, JsonOptions));
}
