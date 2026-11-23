using System.Globalization;
using System.Text.RegularExpressions;

namespace Wayck.Backend;

internal static class Launcher
{
    static string Home => Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
    static string UsageFile => Path.Combine(Home, ".local/share/wayck_uso.txt");

    static string Icon(string icon)
    {
        if(icon=="")return ""; icon=icon.Replace("~",Home);
        if(Path.IsPathRooted(icon))return File.Exists(icon)?icon:"";
        if(icon.Contains('/')||icon.Contains('\\')||icon=="."||icon=="..")return "";
        string[] roots={"/usr/share/icons/Papirus/48x48/apps","/usr/share/icons/Papirus-Dark/48x48/apps","/usr/share/icons/hicolor/scalable/apps","/usr/share/icons/hicolor/256x256/apps","/usr/share/icons/hicolor/128x128/apps","/usr/share/icons/hicolor/48x48/apps","/usr/share/pixmaps",Home+"/.local/share/icons/hicolor/scalable/apps",Home+"/.local/share/icons/hicolor/256x256/apps",Home+"/.local/share/icons/hicolor/128x128/apps",Home+"/.local/share/icons/hicolor/48x48/apps",Home+"/.local/share/icons/Papirus/48x48/apps","/var/lib/flatpak/exports/share/icons/hicolor/128x128/apps","/var/lib/flatpak/exports/share/icons/hicolor/64x64/apps","/var/lib/flatpak/exports/share/icons/hicolor/scalable/apps",Home+"/.local/share/flatpak/exports/share/icons/hicolor/128x128/apps",Home+"/.local/share/flatpak/exports/share/icons/hicolor/64x64/apps",Home+"/.local/share/flatpak/exports/share/icons/hicolor/scalable/apps"};
        foreach(var root in roots)foreach(var ext in new[]{"svg","png","xpm"}){var p=Path.Combine(root,icon+"."+ext);if(File.Exists(p))return p;}
        return File.Exists("/usr/share/icons/Papirus/48x48/apps/terminal.svg")?"/usr/share/icons/Papirus/48x48/apps/terminal.svg":"";
    }

    static App? ReadDesktop(string file)
    {
        string[] lines;try{lines=File.ReadAllLines(file);}catch{return null;}
        bool inside=false;string name="",pt="",icon="",exec="";
        foreach(var raw in lines){var l=raw.Trim();if(l.StartsWith('[')){inside=l=="[Desktop Entry]";continue;}if(!inside||l==""||l.StartsWith('#'))continue;int i=l.IndexOf('=');if(i<0)continue;var k=l[..i];var v=l[(i+1)..];if((k=="NoDisplay"||k=="Hidden")&&v.Equals("true",StringComparison.OrdinalIgnoreCase))return null;if(k=="Name")name=v;if(k=="Name[pt_BR]")pt=v;if(k=="Icon")icon=v;if(k=="Exec")exec=v;}
        if(pt!="")name=pt;return name==""||exec==""?null:new App(name,Icon(icon),exec);
    }

    static List<App> LoadApps()
    {
        string[] dirs={"/usr/share/applications","/usr/local/share/applications","/var/lib/flatpak/exports/share/applications",Home+"/.local/share/applications",Home+"/.local/share/flatpak/exports/share/applications"};
        var result=new List<App>();var seen=new HashSet<string>();
        foreach(var d in dirs)if(Directory.Exists(d))foreach(var f in Directory.GetFiles(d,"*.desktop").Order()){var a=ReadDesktop(f);if(a!=null&&seen.Add(a.Nome))result.Add(a);}
        return result.OrderBy(a=>a.Nome,StringComparer.OrdinalIgnoreCase).ToList();
    }

    static Dictionary<string,int> ReadUsage()
    {
        var r=new Dictionary<string,int>();if(!File.Exists(UsageFile))return r;
        foreach(var l in File.ReadAllLines(UsageFile)){int i=l.LastIndexOf('\t');if(i>0&&int.TryParse(l[(i+1)..],out int n))r[l[..i]]=n;}return r;
    }

    internal static void Usage(string name)
    {
        if(name==""||name.Length>512)return;var u=ReadUsage();u[name]=Math.Min(int.MaxValue,u.GetValueOrDefault(name)+1);
        Directory.CreateDirectory(Path.GetDirectoryName(UsageFile)!);File.WriteAllLines(UsageFile+".tmp",u.OrderBy(x=>x.Key).Select(x=>x.Key+"\t"+x.Value));File.Move(UsageFile+".tmp",UsageFile,true);
    }

    internal static List<App> Filter(string text)
    {
        var u=ReadUsage();var apps=LoadApps().Where(a=>a.Nome.Contains(text,StringComparison.OrdinalIgnoreCase)).OrderByDescending(a=>u.GetValueOrDefault(a.Nome)).Take(15).ToList();
        string n=Calculator.Calculate(text);if(n!="")apps.Insert(0,new App(text.Trim()+" = "+n,Icon("accessories-calculator"),"@copy:"+n));else if(apps.Count==0&&text.Trim()!="")apps.Add(new App(text,Icon("kitty"),"@term:"+text));return apps;
    }

    static string[] Split(string s)
    {
        var list=new List<string>();string part="";char quote='\0';bool esc=false;foreach(char c in s){if(esc){part+=c;esc=false;continue;}if(quote!='\''&&c=='\\'){esc=true;continue;}if(quote=='\0'&&(c=='\''||c=='"')){quote=c;continue;}if(quote!='\0'&&c==quote){quote='\0';continue;}if(quote=='\0'&&char.IsWhiteSpace(c)){if(part!=""){list.Add(part);part="";}continue;}part+=c;}if(esc||quote!='\0')return Array.Empty<string>();if(part!="")list.Add(part);return list.ToArray();
    }

    internal static void RunApp(string cmd,string app)
    {
        if(cmd.StartsWith("@term:")){string[] terms=Split(Environment.GetEnvironmentVariable("TERMINAL")??"");if(terms.Length==0||!BackendProcess.ProgramExists(terms[0]))terms=new[]{"kitty","alacritty","foot","wezterm","konsole","gnome-terminal","kgx","xterm"}.Where(BackendProcess.ProgramExists).Take(1).ToArray();if(terms.Length==0)return;string shell=Environment.GetEnvironmentVariable("SHELL")??"/bin/sh";string script=cmd[6..]+"; exec '"+shell.Replace("'","'\\''")+"'";string name=Path.GetFileName(terms[0]);var a=terms.ToList();a.AddRange(name is "gnome-terminal" or "kgx"?new[]{"--","sh","-lc",script}:name=="wezterm"?new[]{"start","--","sh","-lc",script}:new[]{"-e","sh","-lc",script});BackendProcess.Detached(a.ToArray());return;}
        if(cmd.StartsWith("@copy:")){BackendProcess.Start("wl-copy",Array.Empty<string>(),cmd[6..]);return;}
        var parts=Split(cmd);var clean=new List<string>();foreach(var p in parts){if(new[]{"%f","%F","%u","%U","%i","%d","%D","%n","%N","%v","%m"}.Contains(p))continue;string v=Regex.Replace(p.Replace("%c",app),@"%(?:[fFuUdDnNickvm])","");if(v!="")clean.Add(v);}if(clean.Count>0&&BackendProcess.ProgramExists(clean[0]))BackendProcess.Detached(clean.ToArray());
    }
}
