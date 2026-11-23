using System.Globalization;

namespace Wayck.Backend;

internal static class Calculator
{
    internal static string Calculate(string text)
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
}
