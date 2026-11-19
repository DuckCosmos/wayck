use meval::Context;
use std::collections::HashMap;
use std::fs;
use std::path::PathBuf;

pub fn calculate(input: &str) -> Option<String> {
    let mut expression = input.trim().replace('×', "*").replace('÷', "/").replace('^', "^");
    expression = expression.replace('x', "*").replace('X', "*");
    if expression.is_empty() || expression.len() > 120 || !expression.chars().any(|c| c.is_ascii_digit()) {
        return None;
    }
    let decimal_comma = expression.contains(',');
    expression = expression.replace(',', ".");
    let mut context = Context::new();
    context.var("pi", std::f64::consts::PI);
    context.var("e", std::f64::consts::E);
    context.var("tau", std::f64::consts::TAU);
    context.func("abs", f64::abs);
    context.func("acos", f64::acos);
    context.func("asin", f64::asin);
    context.func("atan", f64::atan);
    context.func("ceil", f64::ceil);
    context.func("cos", f64::cos);
    context.func("cosh", f64::cosh);
    context.func("exp", f64::exp);
    context.func("floor", f64::floor);
    context.func("ln", f64::ln);
    context.func("log", f64::ln);
    context.func("log10", f64::log10);
    context.func("log2", f64::log2);
    context.func("round", f64::round);
    context.func("sin", f64::sin);
    context.func("sinh", f64::sinh);
    context.func("sqrt", f64::sqrt);
    context.func("tan", f64::tan);
    context.func("tanh", f64::tanh);
    let value = expression.parse::<meval::Expr>().ok()?.eval_with_context(context).ok()?;
    if !value.is_finite() {
        return None;
    }
    let result = if value.fract() == 0.0 && value >= i64::MIN as f64 && value < i64::MAX as f64 {
        format!("{}", value as i64)
    } else {
        format!("{value:.12}")
            .trim_end_matches('0')
            .trim_end_matches('.')
            .to_string()
    };
    Some(if decimal_comma { result.replace('.', ",") } else { result })
}

fn usage_file() -> Option<PathBuf> {
    Some(dirs::home_dir()?.join(".local/share/wayck_uso.txt"))
}

pub fn read_usage() -> HashMap<String, u64> {
    let mut usage = HashMap::new();
    if let Some(path) = usage_file() {
        if let Ok(contents) = fs::read_to_string(path) {
            for line in contents.lines() {
                if let Some((name, count)) = line.rsplit_once('\t') {
                    if let Ok(count) = count.parse::<u64>() {
                        usage.insert(name.to_string(), count);
                    }
                }
            }
        }
    }
    usage
}

pub fn register_usage(name: &str) {
    if name.is_empty() || name.len() > 512 {
        return;
    }
    let Some(path) = usage_file() else { return };
    let mut usage = read_usage();
    let count = usage.entry(name.to_string()).or_insert(0);
    *count = count.saturating_add(1).min(i32::MAX as u64);
    if let Some(parent) = path.parent() {
        if fs::create_dir_all(parent).is_err() { return; }
    }
    let mut entries: Vec<_> = usage.into_iter().collect();
    entries.sort_by(|a, b| a.0.cmp(&b.0));
    let data = entries.into_iter().map(|(name, count)| format!("{name}\t{count}\n")).collect::<String>();
    let temp = path.with_extension(format!("tmp.{}", std::process::id()));
    if fs::write(&temp, data).is_ok() {
        use std::os::unix::fs::PermissionsExt;
        let _ = fs::set_permissions(&temp, fs::Permissions::from_mode(0o600));
        let _ = fs::rename(temp, path);
    }
}
