using System.Text.Json;

namespace Wayck.Backend;

internal static class Program
{
    static readonly JsonSerializerOptions JsonOptions = new() { PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower };

    static int Main(string[] args)
    {
        try
        {
            if (args.Length == 0) { string? line; while ((line = Console.ReadLine()) != null) Print(Launcher.Filter(line)); return 0; }
            string A(int i) => args.Length > i ? args[i] : "";
            switch (args[0])
            {
                case "--monitor": SystemMonitor.Run(); break;
                case "--filter": Print(Launcher.Filter(A(1))); break;
                case "--exec": if (args.Length > 2) { Launcher.Usage(A(1)); Launcher.RunApp(A(2), A(1)); } break;
                case "--clipboard-list": Print(Clipboard.List(A(1))); break;
                case "--clipboard-copy": Clipboard.Copy(A(1)); break;
                case "--clipboard-delete": Clipboard.Delete(A(1)); break;
                case "--clipboard-clear":
                    Clipboard.Clear();
                    break;
                case "--check_version": Console.WriteLine(Update.CheckVersion().Available.ToString().ToLowerInvariant()); break;
                case "--version_info": Print(Update.CheckVersion()); break;
            }
            return 0;
        }
        catch (Exception e) { Console.Error.WriteLine("Wayck backend: " + e.Message); return 1; }
    }

    static void Print(object x) => Console.WriteLine(JsonSerializer.Serialize(x, JsonOptions));
}
