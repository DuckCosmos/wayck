namespace Wayck.Backend;

internal static class Update
{
    internal static VersionInfo CheckVersion()
    {
        string local="";string exe=Environment.ProcessPath??"";var paths=new List<string>();if(exe!=""){string dir=Path.GetDirectoryName(exe)!;paths.Add(Path.Combine(dir,"version.txt"));for(int i=0;i<3;i++)dir=Path.GetDirectoryName(dir)??dir;paths.Add(Path.Combine(dir,"version.txt"));}paths.Add(Path.Combine(Environment.CurrentDirectory,"version.txt"));foreach(var p in paths)if(File.Exists(p)){local=File.ReadAllText(p).Trim();break;}
        using var http=new HttpClient{Timeout=TimeSpan.FromSeconds(8)};http.DefaultRequestHeaders.UserAgent.ParseAdd("Wayck-Updater/1.0");string remote=http.GetStringAsync("https://raw.githubusercontent.com/DuckCosmos/wayck/main/version.txt").GetAwaiter().GetResult();if(remote.Length>256)remote=remote[..256];remote=remote.Trim();return new VersionInfo(local,remote,local!=""&&remote!=""&&local!=remote);
    }
}
