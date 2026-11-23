using System.Diagnostics;
using System.Globalization;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Text.RegularExpressions;

record App(string Nome, [property: JsonPropertyName("icone_path")] string IconePath, string Exec);
record Clip(string ID, string Content, [property: JsonPropertyName("is_image")] bool IsImage, string Path);
record VersionInfo(string Local, string Remote, bool Available);

static class Program
{
    static readonly JsonSerializerOptions JsonOptions = new() { PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower };
    static string Home => Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
    static string UsageFile => Path.Combine(Home, ".local/share/wayck_uso.txt");
    static string Prefix => "wayck_clip_" + (Environment.GetEnvironmentVariable("UID") ?? "0") + "_";

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
    static string Output(string file, params string[] args)
    {
        try { var p = new ProcessStartInfo(file) { RedirectStandardOutput=true, UseShellExecute=false }; foreach(var a in args)p.ArgumentList.Add(a); using var proc=Process.Start(p)!; string s=proc.StandardOutput.ReadToEnd(); proc.WaitForExit(); return proc.ExitCode==0?s:""; } catch { return ""; }
    }
    static void Start(string file, string[] args, string? input=null)
    {
        try { var p=new ProcessStartInfo(file){UseShellExecute=false,RedirectStandardInput=input!=null}; foreach(var a in args)p.ArgumentList.Add(a); using var proc=Process.Start(p)!; if(input!=null){proc.StandardInput.Write(input);proc.StandardInput.Close();} } catch {}
    }
    static bool Exists(string p)=>File.Exists(p);
    static string Icon(string icon)
    {
        if(icon=="")return ""; icon=icon.Replace("~",Home);
        if(Path.IsPathRooted(icon))return Exists(icon)?icon:"";
        if(icon.Contains('/')||icon.Contains('\\')||icon=="."||icon=="..")return "";
        string[] roots={"/usr/share/icons/Papirus/48x48/apps","/usr/share/icons/Papirus-Dark/48x48/apps","/usr/share/icons/hicolor/scalable/apps","/usr/share/icons/hicolor/256x256/apps","/usr/share/icons/hicolor/128x128/apps","/usr/share/icons/hicolor/48x48/apps","/usr/share/pixmaps",Home+"/.local/share/icons/hicolor/scalable/apps",Home+"/.local/share/icons/hicolor/256x256/apps",Home+"/.local/share/icons/hicolor/128x128/apps",Home+"/.local/share/icons/hicolor/48x48/apps",Home+"/.local/share/icons/Papirus/48x48/apps","/var/lib/flatpak/exports/share/icons/hicolor/128x128/apps","/var/lib/flatpak/exports/share/icons/hicolor/64x64/apps","/var/lib/flatpak/exports/share/icons/hicolor/scalable/apps",Home+"/.local/share/flatpak/exports/share/icons/hicolor/128x128/apps",Home+"/.local/share/flatpak/exports/share/icons/hicolor/64x64/apps",Home+"/.local/share/flatpak/exports/share/icons/hicolor/scalable/apps"};
        foreach(var root in roots)foreach(var ext in new[]{"svg","png","xpm"}){var p=Path.Combine(root,icon+"."+ext);if(Exists(p))return p;}
        return Exists("/usr/share/icons/Papirus/48x48/apps/terminal.svg")?"/usr/share/icons/Papirus/48x48/apps/terminal.svg":"";
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
    static void Usage(string name)
    {
        if(name==""||name.Length>512)return;var u=ReadUsage();u[name]=Math.Min(int.MaxValue,u.GetValueOrDefault(name)+1);
        Directory.CreateDirectory(Path.GetDirectoryName(UsageFile)!);File.WriteAllLines(UsageFile+".tmp",u.OrderBy(x=>x.Key).Select(x=>x.Key+"\t"+x.Value));File.Move(UsageFile+".tmp",UsageFile,true);
    }
    static List<App> Filter(string text)
    {
        var u=ReadUsage();var apps=LoadApps().Where(a=>a.Nome.Contains(text,StringComparison.OrdinalIgnoreCase)).OrderByDescending(a=>u.GetValueOrDefault(a.Nome)).Take(15).ToList();
        string n=Calc(text);if(n!="")apps.Insert(0,new App(text.Trim()+" = "+n,Icon("accessories-calculator"),"@copy:"+n));else if(apps.Count==0&&text.Trim()!="")apps.Add(new App(text,Icon("kitty"),"@term:"+text));return apps;
    }
    static string Calc(string text)
    {
        string s=text.Trim().Replace("×","*").Replace("÷","/").Replace('x','*').Replace('X','*').Replace(',','.');if(s.Length==0||s.Length>120||!s.Any(char.IsDigit))return "";
        try{var p=new Parser(s);double n=p.Add();p.Skip();if(p.Pos!=s.Length||double.IsNaN(n)||double.IsInfinity(n))return "";string v=n==Math.Truncate(n)&&n>=long.MinValue&&n<long.MaxValue?((long)n).ToString():n.ToString("0.############",CultureInfo.InvariantCulture);return text.Contains(',')?v.Replace('.',','):v;}catch{return "";}
    }
    sealed class Parser(string s)
    {
        public int Pos;public void Skip(){while(Pos<s.Length&&char.IsWhiteSpace(s[Pos]))Pos++;}
        bool Take(char c){Skip();if(Pos<s.Length&&s[Pos]==c){Pos++;return true;}return false;}
        public double Add(){double n=Mul();while(true){if(Take('+'))n+=Mul();else if(Take('-'))n-=Mul();else return n;}}
        double Mul(){double n=Pow();while(true){if(Take('*'))n*=Pow();else if(Take('/'))n/=Pow();else return n;}}
        double Pow(){double n=Unary();return Take('^')?Math.Pow(n,Pow()):n;}
        double Unary(){if(Take('+'))return Unary();if(Take('-'))return -Unary();return Atom();}
        double Atom(){Skip();if(Take('(')){double n=Add();if(!Take(')'))throw new Exception();return n;}int start=Pos;while(Pos<s.Length&&(char.IsDigit(s[Pos])||s[Pos]=='.'))Pos++;if(start<Pos)return double.Parse(s[start..Pos],CultureInfo.InvariantCulture);start=Pos;while(Pos<s.Length&&char.IsLetter(s[Pos]))Pos++;if(start==Pos)throw new Exception();string name=s[start..Pos].ToLowerInvariant();if(Take('(')){double a=Add();if(!Take(')'))throw new Exception();return name switch{"abs"=>Math.Abs(a),"acos"=>Math.Acos(a),"asin"=>Math.Asin(a),"atan"=>Math.Atan(a),"ceil"=>Math.Ceiling(a),"cos"=>Math.Cos(a),"cosh"=>Math.Cosh(a),"exp"=>Math.Exp(a),"floor"=>Math.Floor(a),"ln" or "log"=>Math.Log(a),"log10"=>Math.Log10(a),"log2"=>Math.Log2(a),"round"=>Math.Round(a,MidpointRounding.AwayFromZero),"sin"=>Math.Sin(a),"sinh"=>Math.Sinh(a),"sqrt"=>Math.Sqrt(a),"tan"=>Math.Tan(a),"tanh"=>Math.Tanh(a),_=>throw new Exception()};}return name switch{"pi"=>Math.PI,"e"=>Math.E,"tau"=>Math.PI*2,_=>throw new Exception()};}
    }
    static string[] Split(string s)
    {
        var list=new List<string>();string part="";char quote='\0';bool esc=false;foreach(char c in s){if(esc){part+=c;esc=false;continue;}if(quote!='\''&&c=='\\'){esc=true;continue;}if(quote=='\0'&&(c=='\''||c=='"')){quote=c;continue;}if(quote!='\0'&&c==quote){quote='\0';continue;}if(quote=='\0'&&char.IsWhiteSpace(c)){if(part!=""){list.Add(part);part="";}continue;}part+=c;}if(esc||quote!='\0')return Array.Empty<string>();if(part!="")list.Add(part);return list.ToArray();
    }
    static bool ProgramExists(string name)
    {
        if(name.Contains('/'))return File.Exists(name)&&(File.GetUnixFileMode(name)&UnixFileMode.UserExecute)!=0;
        foreach(var d in (Environment.GetEnvironmentVariable("PATH")??"").Split(':')){string p=Path.Combine(d,name);if(File.Exists(p)&&(File.GetUnixFileMode(p)&UnixFileMode.UserExecute)!=0)return true;}return false;
    }
    static void Detached(string[] args){if(args.Length==0)return;try{var p=new ProcessStartInfo(args[0]){UseShellExecute=false};foreach(var a in args.Skip(1))p.ArgumentList.Add(a);Process.Start(p);}catch{}}
    static void RunApp(string cmd,string app)
    {
        if(cmd.StartsWith("@term:")){string[] terms=Split(Environment.GetEnvironmentVariable("TERMINAL")??"");if(terms.Length==0||!ProgramExists(terms[0]))terms=new[]{"kitty","alacritty","foot","wezterm","konsole","gnome-terminal","kgx","xterm"}.Where(ProgramExists).Take(1).ToArray();if(terms.Length==0)return;string shell=Environment.GetEnvironmentVariable("SHELL")??"/bin/sh";string script=cmd[6..]+"; exec '"+shell.Replace("'","'\\''")+"'";string name=Path.GetFileName(terms[0]);var a=terms.ToList();a.AddRange(name is "gnome-terminal" or "kgx"?new[]{"--","sh","-lc",script}:name=="wezterm"?new[]{"start","--","sh","-lc",script}:new[]{"-e","sh","-lc",script});Detached(a.ToArray());return;}
        if(cmd.StartsWith("@copy:")){Start("wl-copy",Array.Empty<string>(),cmd[6..]);return;}
        var parts=Split(cmd);var clean=new List<string>();foreach(var p in parts){if(new[]{"%f","%F","%u","%U","%i","%d","%D","%n","%N","%v","%m"}.Contains(p))continue;string v=Regex.Replace(p.Replace("%c",app),@"%(?:[fFuUdDnNickvm])","");if(v!="")clean.Add(v);}if(clean.Count>0&&ProgramExists(clean[0]))Detached(clean.ToArray());
    }
    static bool ValidId(string id)=>id.Length>0&&id.All(char.IsAsciiDigit);
    static string DecodeImage(string id)
    {
        string path=Path.Combine(Path.GetTempPath(),Prefix+id+".png");if(File.Exists(path))return path;
        try{var info=new ProcessStartInfo("cliphist"){RedirectStandardOutput=true,UseShellExecute=false};info.ArgumentList.Add("decode");info.ArgumentList.Add(id);using var p=Process.Start(info)!;using var f=File.Create(path);p.StandardOutput.BaseStream.CopyTo(f);p.WaitForExit();if(p.ExitCode!=0){File.Delete(path);return "";}File.SetUnixFileMode(path,UnixFileMode.UserRead|UnixFileMode.UserWrite);return path;}catch{try{File.Delete(path);}catch{}return "";}
    }
    static List<Clip> ClipboardList(string query)
    {
        var result=new List<Clip>();foreach(var line in Output("cliphist","list").Split('\n')){var p=line.Split('\t',2);if(p.Length!=2||!ValidId(p[0])||!p[1].Contains(query,StringComparison.OrdinalIgnoreCase))continue;bool image=p[1].StartsWith("[[ binary data")&&p[1].Contains("png",StringComparison.OrdinalIgnoreCase);string path=image?DecodeImage(p[0]):"";if(image&&path=="")continue;result.Add(new Clip(p[0],p[1].Replace('\n',' '),image,path));if(result.Count==50)break;}return result;
    }
    static void ClipboardCopy(string id)
    {
        if(!ValidId(id))return;try{var a=new ProcessStartInfo("cliphist"){RedirectStandardOutput=true,UseShellExecute=false};a.ArgumentList.Add("decode");a.ArgumentList.Add(id);using var src=Process.Start(a)!;var b=new ProcessStartInfo("wl-copy"){RedirectStandardInput=true,UseShellExecute=false};using var dst=Process.Start(b)!;src.StandardOutput.BaseStream.CopyTo(dst.StandardInput.BaseStream);dst.StandardInput.Close();src.WaitForExit();dst.WaitForExit();}catch{}
    }
    static VersionInfo CheckVersion()
    {
        string local="";string exe=Environment.ProcessPath??"";var paths=new List<string>();if(exe!=""){string dir=Path.GetDirectoryName(exe)!;paths.Add(Path.Combine(dir,"version.txt"));for(int i=0;i<3;i++)dir=Path.GetDirectoryName(dir)??dir;paths.Add(Path.Combine(dir,"version.txt"));}paths.Add(Path.Combine(Environment.CurrentDirectory,"version.txt"));foreach(var p in paths)if(File.Exists(p)){local=File.ReadAllText(p).Trim();break;}
        using var http=new HttpClient{Timeout=TimeSpan.FromSeconds(8)};http.DefaultRequestHeaders.UserAgent.ParseAdd("Wayck-Updater/1.0");string remote=http.GetStringAsync("https://raw.githubusercontent.com/DuckCosmos/wayck/main/version.txt").GetAwaiter().GetResult();if(remote.Length>256)remote=remote[..256];remote=remote.Trim();return new VersionInfo(local,remote,local!=""&&remote!=""&&local!=remote);
    }
    static double Round(double n)=>Math.Round(n,1,MidpointRounding.AwayFromZero);
    static double Mem(string key){foreach(var l in File.ReadLines("/proc/meminfo"))if(l.StartsWith(key+":"))return double.Parse(Regex.Match(l,@"\d+").Value);return 0;}
    static double? Temperature()
    {
        double max=-999;foreach(var d in Directory.GetDirectories("/sys/class/hwmon","hwmon*")){string chip=File.Exists(d+"/name")?File.ReadAllText(d+"/name").Trim().ToLower():"";bool cpu=chip.Contains("coretemp")||chip.Contains("k10temp")||chip.Contains("zenpower");foreach(var f in Directory.GetFiles(d,"temp*_input")){string label=File.Exists(f[..^6]+"_label")?File.ReadAllText(f[..^6]+"_label").ToLower():"";if(!cpu&&!new[]{"cpu","package","tctl","tdie","core"}.Any(label.Contains))continue;if(double.TryParse(File.ReadAllText(f).Trim(),out double n)){n/=1000;if(n>=-20&&n<=150)max=Math.Max(max,n);}}}return max==-999?null:Round(max);
    }
    static (bool,double?,double?,double?,double?,double?) Gpu()
    {
        string s=Output("nvidia-smi","--query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total","--format=csv,noheader,nounits").Split('\n').FirstOrDefault()??"";var p=s.Split(',');if(p.Length<4)return(false,null,null,null,null,null);double?[] n=p.Select(x=>double.TryParse(x.Trim(),NumberStyles.Any,CultureInfo.InvariantCulture,out double v)?v:null).ToArray();double? vram=n[2]!=null&&n[3]>0?Round(n[2]!.Value/n[3]!.Value*100):null;return(true,n[0]==null?null:Round(Math.Clamp(n[0]!.Value,0,100)),n[1]==null?null:Round(n[1]!.Value),vram,n[2],n[3]);
    }
    static void Monitor()
    {
        long ot=0,oi=0,od=0,ou=0;DateTime last=DateTime.UtcNow;bool first=true;
        while(true){var start=DateTime.UtcNow;var c=File.ReadLines("/proc/stat").First().Split(' ',StringSplitOptions.RemoveEmptyEntries).Skip(1).Take(8).Select(x=>long.TryParse(x,out long v)?v:0).ToArray();long total=c.Sum(),idle=c[3]+c[4];double cpu=!first&&total>ot?Round((1-(double)(idle-oi)/(total-ot))*100):0;ot=total;oi=idle;
            double mt=Mem("MemTotal"),mu=Math.Max(0,mt-Mem("MemAvailable"));var d=Output("df","-B1","--output=size,used,avail","/").Split('\n').Skip(1).FirstOrDefault()??"";var dv=d.Split(' ',StringSplitOptions.RemoveEmptyEntries).Select(x=>double.TryParse(x,out double v)?v:0).ToArray();double dt=dv.Length>0?dv[0]:0,du=dv.Length>1?dv[1]:0;
            long down=0,up=0;foreach(var l in File.ReadLines("/proc/net/dev").Skip(2)){var pair=l.Split(':',2);if(pair.Length<2||pair[0].Trim()=="lo")continue;var v=pair[1].Split(' ',StringSplitOptions.RemoveEmptyEntries);if(v.Length>=9){long.TryParse(v[0],out long a);long.TryParse(v[8],out long b);down+=a;up+=b;}}
            double elapsed=Math.Max(.001,(DateTime.UtcNow-last).TotalSeconds),dn=first?0:Round(Math.Max(0,down-od)/1024/elapsed),un=first?0:Round(Math.Max(0,up-ou)/1024/elapsed);od=down;ou=up;last=DateTime.UtcNow;first=false;var g=Gpu();
            Print(new{cpu_percent=cpu,ram_percent=mt>0?Round(mu/mt*100):0,ram_used_mb=Round(mu/1024),ram_total_mb=Round(mt/1024),disk_percent=dt>0?Round(du/dt*100):0,disk_used_gib=Round(du/1073741824),disk_total_gib=Round(dt/1073741824),gpu_available=g.Item1,gpu_percent=g.Item2,gpu_temp_c=g.Item3,gpu_vram_percent=g.Item4,gpu_vram_used_mb=g.Item5,gpu_vram_total_mb=g.Item6,network_down_kib_s=dn,network_up_kib_s=un,temperature_c=Temperature()});
            int wait=1000-(int)(DateTime.UtcNow-start).TotalMilliseconds;if(wait>0)Thread.Sleep(wait);
        }
    }
}
