use crate::utils;
use serde::Serialize;
use std::collections::HashSet;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::os::unix::process::CommandExt;
use std::os::unix::fs::PermissionsExt;

#[derive(Clone, Serialize)]
pub struct AppData {
    nome: String,
    icone_path: String,
    exec: String,
}

fn application_dirs() -> Vec<PathBuf> {
    let home = dirs::home_dir().unwrap_or_default();
    vec![
        PathBuf::from("/usr/share/applications"),
        PathBuf::from("/usr/local/share/applications"),
        PathBuf::from("/var/lib/flatpak/exports/share/applications"),
        home.join(".local/share/applications"),
        home.join(".local/share/flatpak/exports/share/applications"),
    ]
}

fn icon_path(icon: &str) -> String {
    if icon.is_empty() { return String::new(); }
    let candidate = PathBuf::from(icon.replace('~', &dirs::home_dir().unwrap_or_default().to_string_lossy()));
    if candidate.is_absolute() { return if candidate.is_file() { candidate.to_string_lossy().to_string() } else { String::new() }; }
    if icon.contains('/') || icon.contains('\\') || icon == "." || icon == ".." { return String::new(); }
    let home = dirs::home_dir().unwrap_or_default();
    let roots = vec![
        PathBuf::from("/usr/share/icons/Papirus/48x48/apps"), PathBuf::from("/usr/share/icons/Papirus-Dark/48x48/apps"),
        PathBuf::from("/usr/share/icons/hicolor/scalable/apps"), PathBuf::from("/usr/share/icons/hicolor/256x256/apps"),
        PathBuf::from("/usr/share/icons/hicolor/128x128/apps"), PathBuf::from("/usr/share/icons/hicolor/48x48/apps"),
        PathBuf::from("/usr/share/pixmaps"), home.join(".local/share/icons/hicolor/scalable/apps"),
        home.join(".local/share/icons/hicolor/256x256/apps"), home.join(".local/share/icons/hicolor/128x128/apps"),
        home.join(".local/share/icons/hicolor/48x48/apps"), home.join(".local/share/icons/Papirus/48x48/apps"),
        PathBuf::from("/var/lib/flatpak/exports/share/icons/hicolor/128x128/apps"),
        PathBuf::from("/var/lib/flatpak/exports/share/icons/hicolor/64x64/apps"),
        PathBuf::from("/var/lib/flatpak/exports/share/icons/hicolor/scalable/apps"),
        home.join(".local/share/flatpak/exports/share/icons/hicolor/128x128/apps"),
        home.join(".local/share/flatpak/exports/share/icons/hicolor/64x64/apps"),
        home.join(".local/share/flatpak/exports/share/icons/hicolor/scalable/apps"),
    ];
    for root in roots { for ext in ["svg", "png", "xpm"] {
        let path = root.join(format!("{icon}.{ext}"));
        if path.is_file() { return path.to_string_lossy().to_string(); }
    }}
    let fallback = Path::new("/usr/share/icons/Papirus/48x48/apps/terminal.svg");
    if fallback.is_file() { fallback.to_string_lossy().to_string() } else { String::new() }
}

fn read_desktop(path: &Path) -> Option<AppData> {
    let text = fs::read_to_string(path).ok()?;
    let mut section = false;
    let mut name = String::new();
    let mut icon = String::new();
    let mut exec = String::new();
    let mut name_pt = String::new();
    for raw in text.lines() {
        let line = raw.trim();
        if line.starts_with('[') { section = line == "[Desktop Entry]"; continue; }
        if !section || line.is_empty() || line.starts_with('#') { continue; }
        let Some((key, value)) = line.split_once('=') else { continue };
        match key {
            "NoDisplay" | "Hidden" if value.eq_ignore_ascii_case("true") => return None,
            "Name[pt_BR]" => name_pt = value.to_string(),
            "Name" => name = value.to_string(),
            "Icon" => icon = value.to_string(),
            "Exec" => exec = value.to_string(),
            _ => {}
        }
    }
    let name = if !name_pt.is_empty() { name_pt } else { name };
    if name.is_empty() || exec.is_empty() { return None; }
    Some(AppData { nome: name, icone_path: icon_path(&icon), exec })
}

fn load_apps() -> Vec<AppData> {
    let mut apps = Vec::new();
    let mut seen = HashSet::new();
    for dir in application_dirs() {
        let Ok(entries) = fs::read_dir(dir) else { continue };
        let mut paths: Vec<_> = entries.flatten().map(|e| e.path()).filter(|p| p.extension().is_some_and(|e| e == "desktop")).collect();
        paths.sort();
        for path in paths {
            if let Some(app) = read_desktop(&path) {
                if seen.insert(app.nome.clone()) { apps.push(app); }
            }
        }
    }
    apps.sort_by_key(|app| app.nome.to_lowercase());
    apps
}

pub fn filter_apps(text: &str) -> Vec<AppData> {
    let query = text.to_lowercase();
    let usage = utils::read_usage();
    let mut apps: Vec<_> = load_apps().into_iter().filter(|app| app.nome.to_lowercase().contains(&query)).collect();
    apps.sort_by_key(|app| std::cmp::Reverse(*usage.get(&app.nome).unwrap_or(&0)));
    apps.truncate(15);
    if let Some(value) = utils::calculate(text) {
        apps.insert(0, AppData { nome: format!("{} = {}", text.trim(), value), icone_path: icon_path("accessories-calculator"), exec: format!("@copy:{value}") });
    } else if apps.is_empty() && !text.trim().is_empty() {
        apps.push(AppData { nome: text.to_string(), icone_path: icon_path("kitty"), exec: format!("@term:{text}") });
    }
    apps
}

fn is_executable(path: &Path) -> bool {
    path.is_file() && fs::metadata(path).map(|metadata| metadata.permissions().mode() & 0o111 != 0).unwrap_or(false)
}

fn which(program: &str) -> Option<PathBuf> {
    if program.contains('/') {
        let path = PathBuf::from(program);
        return if is_executable(&path) { Some(path) } else { None };
    }
    std::env::var_os("PATH").and_then(|paths| std::env::split_paths(&paths).map(|p| p.join(program)).find(|p| is_executable(p)))
}

fn terminal() -> Vec<String> {
    if let Ok(configured) = std::env::var("TERMINAL") {
        if let Some(parts) = shlex::split(&configured) {
            if let Some(first) = parts.first() { if which(first).is_some() { return parts; } }
        }
    }
    for name in ["kitty", "alacritty", "foot", "wezterm", "konsole", "gnome-terminal", "kgx", "xterm"] {
        if let Some(path) = which(name) { return vec![path.to_string_lossy().to_string()]; }
    }
    Vec::new()
}

fn open_terminal(command: &str) {
    let term = terminal();
    if term.is_empty() { return; }
    let shell = std::env::var("SHELL").unwrap_or_else(|_| "/bin/sh".into());
    let quoted_shell = format!("'{}'", shell.replace('\'', "'\\''"));
    let shell_command = format!("{command}; exec {quoted_shell}");
    let name = Path::new(&term[0]).file_name().unwrap_or_default().to_string_lossy();
    let mut args = term.clone();
    if name == "gnome-terminal" || name == "kgx" { args.extend(["--".into(), "sh".into(), "-lc".into(), shell_command]); }
    else if name == "wezterm" { args.extend(["start".into(), "--".into(), "sh".into(), "-lc".into(), shell_command]); }
    else { args.extend(["-e".into(), "sh".into(), "-lc".into(), shell_command]); }
    let _ = Command::new(&args[0]).args(&args[1..]).stdin(Stdio::null()).stdout(Stdio::null()).stderr(Stdio::null()).process_group(0).spawn();
}

pub fn execute(exec_command: &str, app_name: &str) {
    if let Some(command) = exec_command.strip_prefix("@term:") { open_terminal(command); return; }
    if let Some(value) = exec_command.strip_prefix("@copy:") {
        let _ = Command::new("wl-copy").stdin(Stdio::piped()).spawn().and_then(|mut child| {
            if let Some(mut stdin) = child.stdin.take() { use std::io::Write; let _ = stdin.write_all(value.as_bytes()); }
            child.wait()
        });
        return;
    }
    let Some(parts) = shlex::split(exec_command) else { return };
    let field_codes = regex::Regex::new(r"%(?:[fFuUdDnNickvm])").unwrap();
    let mut cleaned = Vec::new();
    for arg in parts {
        if ["%f", "%F", "%u", "%U", "%i", "%d", "%D", "%n", "%N", "%v", "%m"].contains(&arg.as_str()) { continue; }
        let arg = field_codes.replace_all(&arg.replace("%c", app_name), "");
        if !arg.is_empty() { cleaned.push(arg.into_owned()); }
    }
    if cleaned.is_empty() || which(&cleaned[0]).is_none() { return; }
    let _ = Command::new(&cleaned[0]).args(&cleaned[1..]).stdin(Stdio::null()).stdout(Stdio::null()).stderr(Stdio::null()).process_group(0).spawn();
}
