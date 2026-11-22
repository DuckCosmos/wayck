using System.Text.Json;
using Wayck.Backend;

static void Emit<T>(T value) => Console.WriteLine(JsonSerializer.Serialize(value));

int Run()
{
    var args = Environment.GetCommandLineArgs().Skip(1).ToArray();
    if (args.Length > 0)
    {
        var command = args[0];
        var rest = args.Skip(1).ToArray();
        switch (command)
        {
            case "--monitor":
                Monitor.Run();
                return 0;
            case "--filter":
                Emit(Launcher.FilterApps(rest.FirstOrDefault() ?? ""));
                return 0;
            case "--exec" when rest.Length >= 2:
                Utils.RegisterUsage(rest[0]);
                Launcher.Execute(rest[1], rest[0]);
                return 0;
            case "--clipboard-list":
                Emit(Clipboard.ListItems(rest.FirstOrDefault() ?? ""));
                return 0;
            case "--clipboard-copy" when rest.Length > 0:
                Clipboard.CopyItem(rest[0]);
                return 0;
            case "--clipboard-delete" when rest.Length > 0:
                Clipboard.DeleteItem(rest[0]);
                return 0;
            case "--clipboard-clear":
                Clipboard.Clear();
                return 0;
            case "--check_version":
                Console.WriteLine(Update.Check());
                return 0;
            case "--version_info":
                Emit(Update.CheckInfo());
                return 0;
            default:
                return 0;
        }
    }

    string? query;
    while ((query = Console.ReadLine()) is not null)
    {
        try { Emit(Launcher.FilterApps(query)); }
        catch (Exception ex) { Console.Error.WriteLine($"Erro no launcher: {ex.Message}"); }
    }
    return 0;
}

try { return Run(); }
catch (Exception ex)
{
    Console.Error.WriteLine($"Wayck backend: {ex.Message}");
    return 1;
}