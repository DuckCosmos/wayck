using System.Globalization;
using System.Text;

namespace Wayck.Backend;

internal static class Utils
{
    private static string UsagePath => Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), ".local", "share", "wayck_uso.txt");

    public static string? Calculate(string input)
    {
        var expression = input.Trim().Replace('×', '*').Replace('÷', '/').Replace('^', '^').Replace('x', '*').Replace('X', '*');
        if (expression.Length == 0 || expression.Length > 120 || !expression.Any(char.IsAsciiDigit)) return null;
        var decimalComma = expression.Contains(',');
        expression = expression.Replace(',', '.');
        try
        {
            var parser = new ExpressionParser(expression);
            var value = parser.Parse();
            if (!double.IsFinite(value)) return null;
            string result;
            if (value % 1 == 0 && value >= long.MinValue && value < long.MaxValue)
                result = ((long)value).ToString(CultureInfo.InvariantCulture);
            else
                result = value.ToString("0.############", CultureInfo.InvariantCulture);
            return decimalComma ? result.Replace('.', ',') : result;
        }
        catch { return null; }
    }

    public static Dictionary<string, long> ReadUsage()
    {
        var usage = new Dictionary<string, long>(StringComparer.Ordinal);
        try
        {
            foreach (var line in File.ReadLines(UsagePath))
            {
                var index = line.LastIndexOf('\t');
                if (index <= 0 || !long.TryParse(line[(index + 1)..], out var count)) continue;
                usage[line[..index]] = count;
            }
        }
        catch { }
        return usage;
    }

    public static void RegisterUsage(string name)
    {
        if (name.Length == 0 || name.Length > 512) return;
        try
        {
            var usage = ReadUsage();
            usage[name] = Math.Min(int.MaxValue, usage.GetValueOrDefault(name) + 1);
            var parent = Path.GetDirectoryName(UsagePath)!;
            Directory.CreateDirectory(parent);
            var data = string.Join("", usage.OrderBy(x => x.Key, StringComparer.Ordinal).Select(x => $"{x.Key}\t{x.Value}\n"));
            var temp = UsagePath + $".tmp.{Environment.ProcessId}";
            File.WriteAllText(temp, data);
            File.SetUnixFileMode(temp, UnixFileMode.UserRead | UnixFileMode.UserWrite);
            File.Move(temp, UsagePath, true);
        }
        catch { }
    }

    private sealed class ExpressionParser(string source)
    {
        private readonly string _s = source;
        private int _pos;
        private double Parse()
        {
            var value = AddSub();
            Skip();
            if (_pos != _s.Length) throw new FormatException();
            return value;
        }
        private double AddSub()
        {
            var v = MulDiv();
            while (true) { Skip(); if (Take('+')) v += MulDiv(); else if (Take('-')) v -= MulDiv(); else return v; }
        }
        private double MulDiv()
        {
            var v = Power();
            while (true) { Skip(); if (Take('*')) v *= Power(); else if (Take('/')) v /= Power(); else return v; }
        }
        private double Power()
        {
            var v = Unary(); Skip();
            if (Take('^')) return Math.Pow(v, Power());
            return v;
        }
        private double Unary()
        {
            Skip();
            if (Take('+')) return Unary();
            if (Take('-')) return -Unary();
            return Atom();
        }
        private double Atom()
        {
            Skip();
            if (Take('(')) { var v = AddSub(); Skip(); if (!Take(')')) throw new FormatException(); return v; }
            if (_pos < _s.Length && (char.IsAsciiDigit(_s[_pos]) || _s[_pos] == '.'))
            {
                var start = _pos;
                while (_pos < _s.Length && (char.IsAsciiDigit(_s[_pos]) || _s[_pos] == '.')) _pos++;
                return double.Parse(_s[start.._pos], CultureInfo.InvariantCulture);
            }
            var startName = _pos;
            while (_pos < _s.Length && char.IsLetter(_s[_pos])) _pos++;
            if (startName == _pos) throw new FormatException();
            var name = _s[startName.._pos].ToLowerInvariant();
            Skip();
            if (Take('('))
            {
                var arg = AddSub(); Skip(); if (!Take(')')) throw new FormatException();
                return name switch {
                    "abs" => Math.Abs(arg), "acos" => Math.Acos(arg), "asin" => Math.Asin(arg), "atan" => Math.Atan(arg),
                    "ceil" => Math.Ceiling(arg), "cos" => Math.Cos(arg), "cosh" => Math.Cosh(arg), "exp" => Math.Exp(arg),
                    "floor" => Math.Floor(arg), "ln" or "log" => Math.Log(arg), "log10" => Math.Log10(arg), "log2" => Math.Log2(arg),
                    "round" => Math.Round(arg, MidpointRounding.AwayFromZero), "sin" => Math.Sin(arg), "sinh" => Math.Sinh(arg),
                    "sqrt" => Math.Sqrt(arg), "tan" => Math.Tan(arg), "tanh" => Math.Tanh(arg), _ => throw new FormatException()
                };
            }
            return name switch { "pi" => Math.PI, "e" => Math.E, "tau" => Math.Tau, _ => throw new FormatException() };
        }
        private void Skip() { while (_pos < _s.Length && char.IsWhiteSpace(_s[_pos])) _pos++; }
        private bool Take(char c) { if (_pos < _s.Length && _s[_pos] == c) { _pos++; return true; } return false; }
    }
}