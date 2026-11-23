using System.Text.RegularExpressions;
using System.Globalization;

namespace Wayck.Backend;

internal static class SystemMonitor
{
    static double Round(double n)=>Math.Round(n,1,MidpointRounding.AwayFromZero);

    static double Mem(string key){foreach(var l in File.ReadLines("/proc/meminfo"))if(l.StartsWith(key+":"))return double.Parse(Regex.Match(l,@"\d+").Value);return 0;}

    static double? Temperature()
    {
        double max=-999;foreach(var d in Directory.GetDirectories("/sys/class/hwmon","hwmon*")){string chip=File.Exists(d+"/name")?File.ReadAllText(d+"/name").Trim().ToLower():"";bool cpu=chip.Contains("coretemp")||chip.Contains("k10temp")||chip.Contains("zenpower");foreach(var f in Directory.GetFiles(d,"temp*_input")){string label=File.Exists(f[..^6]+"_label")?File.ReadAllText(f[..^6]+"_label").ToLower():"";if(!cpu&&!new[]{"cpu","package","tctl","tdie","core"}.Any(label.Contains))continue;if(double.TryParse(File.ReadAllText(f).Trim(),out double n)){n/=1000;if(n>=-20&&n<=150)max=Math.Max(max,n);}}}return max==-999?null:Round(max);
    }

    static (bool,double?,double?,double?,double?,double?) Gpu()
    {
        string s=BackendProcess.BackendProcess.Output("nvidia-smi","--query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total","--format=csv,noheader,nounits").Split('\n').FirstOrDefault()??"";var p=s.Split(',');if(p.Length<4)return(false,null,null,null,null,null);double?[] n=p.Select(x=>double.TryParse(x.Trim(),NumberStyles.Any,CultureInfo.InvariantCulture,out double v)?v:null).ToArray();double? vram=n[2]!=null&&n[3]>0?Round(n[2]!.Value/n[3]!.Value*100):null;return(true,n[0]==null?null:Round(Math.Clamp(n[0]!.Value,0,100)),n[1]==null?null:Round(n[1]!.Value),vram,n[2],n[3]);
    }

    internal static void Run()
    {
        long ot=0,oi=0,od=0,ou=0;DateTime last=DateTime.UtcNow;bool first=true;
        while(true){var start=DateTime.UtcNow;var c=File.ReadLines("/proc/stat").First().Split(' ',StringSplitOptions.RemoveEmptyEntries).Skip(1).Take(8).Select(x=>long.TryParse(x,out long v)?v:0).ToArray();long total=c.Sum(),idle=c[3]+c[4];double cpu=!first&&total>ot?Round((1-(double)(idle-oi)/(total-ot))*100):0;ot=total;oi=idle;
            double mt=Mem("MemTotal"),mu=Math.Max(0,mt-Mem("MemAvailable"));var d=Output("df","-B1","--output=size,used,avail","/").Split('\n').Skip(1).FirstOrDefault()??"";var dv=d.Split(' ',StringSplitOptions.RemoveEmptyEntries).Select(x=>double.TryParse(x,out double v)?v:0).ToArray();double dt=dv.Length>0?dv[0]:0,du=dv.Length>1?dv[1]:0;
            long down=0,up=0;foreach(var l in File.ReadLines("/proc/net/dev").Skip(2)){var pair=l.Split(':',2);if(pair.Length<2||pair[0].Trim()=="lo")continue;var v=pair[1].Split(' ',StringSplitOptions.RemoveEmptyEntries);if(v.Length>=9){long.TryParse(v[0],out long a);long.TryParse(v[8],out long b);down+=a;up+=b;}}
            double elapsed=Math.Max(.001,(DateTime.UtcNow-last).TotalSeconds),dn=first?0:Round(Math.Max(0,down-od)/1024/elapsed),un=first?0:Round(Math.Max(0,up-ou)/1024/elapsed);od=down;ou=up;last=DateTime.UtcNow;first=false;var g=Gpu();
            Program.Print(new{cpu_percent=cpu,ram_percent=mt>0?Round(mu/mt*100):0,ram_used_mb=Round(mu/1024),ram_total_mb=Round(mt/1024),disk_percent=dt>0?Round(du/dt*100):0,disk_used_gib=Round(du/1073741824),disk_total_gib=Round(dt/1073741824),gpu_available=g.Item1,gpu_percent=g.Item2,gpu_temp_c=g.Item3,gpu_vram_percent=g.Item4,gpu_vram_used_mb=g.Item5,gpu_vram_total_mb=g.Item6,network_down_kib_s=dn,network_up_kib_s=un,temperature_c=Temperature()});
            int wait=1000-(int)(DateTime.UtcNow-start).TotalMilliseconds;if(wait>0)Thread.Sleep(wait);
        }
    }
}
