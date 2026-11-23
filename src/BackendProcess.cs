using System.Diagnostics;

namespace Wayck.Backend;

internal static class BackendProcess
{
    static string Output(string file, params string[] args)
    {
        try { var p = new ProcessStartInfo(file) { RedirectStandardOutput=true, UseShellExecute=false }; foreach(var a in args)p.ArgumentList.Add(a); using var proc=Process.Start(p)!; string s=proc.StandardOutput.ReadToEnd(); proc.WaitForExit(); return proc.ExitCode==0?s:""; } catch { return ""; }
    }

    static void Start(string file, string[] args, string? input=null)
    {
        try { var p=new ProcessStartInfo(file){UseShellExecute=false,RedirectStandardInput=input!=null}; foreach(var a in args)p.ArgumentList.Add(a); using var proc=Process.Start(p)!; if(input!=null){proc.StandardInput.Write(input);proc.StandardInput.Close();} } catch {}
    }

    static bool ProgramExists(string name)
    {
        if(name.Contains('/'))return File.Exists(name)&&(File.GetUnixFileMode(name)&UnixFileMode.UserExecute)!=0;
        foreach(var d in (Environment.GetEnvironmentVariable("PATH")??"").Split(':')){string p=Path.Combine(d,name);if(File.Exists(p)&&(File.GetUnixFileMode(p)&UnixFileMode.UserExecute)!=0)return true;}return false;
    }

    static void Detached(string[] args){if(args.Length==0)return;try{var p=new ProcessStartInfo(args[0]){UseShellExecute=true};foreach(var a in args.Skip(1))p.ArgumentList.Add(a);Process.Start(p);}catch{}}
}
