namespace Wayck.Backend;

internal static class Clipboard
{
    static string Prefix => "wayck_clip_" + (Environment.GetEnvironmentVariable("UID") ?? "0") + "_";

    static bool ValidId(string id)=>id.Length>0&&id.All(char.IsAsciiDigit);

    static string DecodeImage(string id)
    {
        string path=Path.Combine(Path.GetTempPath(),Prefix+id+".png");if(File.Exists(path))return path;
        try{var info=new ProcessStartInfo("cliphist"){RedirectStandardOutput=true,UseShellExecute=false};info.ArgumentList.Add("decode");info.ArgumentList.Add(id);using var p=Process.BackendProcess.Start(info)!;using var f=File.Create(path);p.StandardOutput.BaseStream.CopyTo(f);p.WaitForExit();if(p.ExitCode!=0){File.Delete(path);return "";}File.SetUnixFileMode(path,UnixFileMode.UserRead|UnixFileMode.UserWrite);return path;}catch{try{File.Delete(path);}catch{}return "";}
    }

    internal static List<Clip> List(string query)
    {
        var result=new List<Clip>();foreach(var line in BackendProcess.Output("cliphist","list").Split('\n')){var p=line.Split('\t',2);if(p.Length!=2||!ValidId(p[0])||!p[1].Contains(query,StringComparison.OrdinalIgnoreCase))continue;bool image=p[1].StartsWith("[[ binary data")&&p[1].Contains("png",StringComparison.OrdinalIgnoreCase);string path=image?DecodeImage(p[0]):"";if(image&&path=="")continue;result.Add(new Clip(p[0],p[1].Replace('\n',' '),image,path));if(result.Count==50)break;}return result;
    }

    internal static void Copy(string id)
    {
        if(!ValidId(id))return;try{var a=new ProcessStartInfo("cliphist"){RedirectStandardOutput=true,UseShellExecute=false};a.ArgumentList.Add("decode");a.ArgumentList.Add(id);using var src=Process.Start(a)!;var b=new ProcessStartInfo("wl-copy"){RedirectStandardInput=true,UseShellExecute=false};using var dst=Process.BackendProcess.Start(b)!;src.StandardOutput.BaseStream.CopyTo(dst.StandardInput.BaseStream);dst.StandardInput.Close();src.WaitForExit();dst.WaitForExit();}catch{}
    }

    internal static void Delete(string id)
    {
        if (ValidId(id)) BackendProcess.Start("cliphist", new[] { "delete" }, id + "\n");
    }

    internal static void Clear()
    {
        BackendProcess.Start("wl-copy", new[] { "--clear" });
        BackendProcess.Start("cliphist", new[] { "wipe" });
        foreach (var file in Directory.GetFiles(Path.GetTempPath(), Prefix + "*.png"))
            try { File.Delete(file); } catch { }
    }
}
