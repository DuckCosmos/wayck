use serde_json::{json, Value};
use std::fs;
use std::io::Write;
use std::os::unix::fs::PermissionsExt;
use std::path::PathBuf;
use std::process::{Command, Stdio};

fn valid_id(value: &str) -> bool { !value.is_empty() && value.bytes().all(|b| b.is_ascii_digit()) }
fn cache_prefix() -> String { format!("wayck_clip_{}_", unsafe { libc::geteuid() }) }
fn image_path(id: &str) -> PathBuf { std::env::temp_dir().join(format!("{}{id}.png", cache_prefix())) }

fn decode_image(id: &str) -> Option<String> {
    let path = image_path(id);
    if path.is_file() { return Some(path.to_string_lossy().to_string()); }
    let mut temporary = tempfile::Builder::new().prefix(&cache_prefix()).suffix(".png").tempfile().ok()?;
    let output = Command::new("cliphist").args(["decode", id]).stdout(Stdio::piped()).stderr(Stdio::null()).spawn().ok()?;
    let mut child = output;
    let mut stdout = child.stdout.take()?;
    std::io::copy(&mut stdout, &mut temporary).ok()?;
    if !child.wait().ok()?.success() { return None; }
    temporary.persist(&path).ok()?;
    let _ = fs::set_permissions(&path, fs::Permissions::from_mode(0o600));
    Some(path.to_string_lossy().to_string())
}

pub fn list_items(term: &str) -> Vec<Value> {
    let output = match Command::new("cliphist").arg("list").output() { Ok(v) if v.status.success() => v, _ => return Vec::new() };
    let query = term.to_lowercase();
    let mut items = Vec::new();
    for line in String::from_utf8_lossy(&output.stdout).lines() {
        let Some((id, content)) = line.split_once('\t') else { continue };
        if !valid_id(id) || (!query.is_empty() && !content.to_lowercase().contains(&query)) { continue; }
        let is_image = content.starts_with("[[ binary data") && content.to_lowercase().contains("png");
        let path = if is_image { decode_image(id) } else { None };
        if is_image && path.is_none() { continue; }
        items.push(json!({
            "id": id,
            "content": if is_image { content.to_string() } else { content.replace('\n', " ") },
            "is_image": is_image,
            "path": path
        }));
        if items.len() >= 50 { break; }
    }
    items
}

pub fn copy_item(id: &str) {
    if !valid_id(id) { return; }
    let mut source = match Command::new("cliphist").args(["decode", id]).stdout(Stdio::piped()).stderr(Stdio::null()).spawn() { Ok(v) => v, Err(_) => return };
    let Some(stdout) = source.stdout.take() else { return };
    let mut destination = match Command::new("wl-copy").stdin(Stdio::from(stdout)).stdout(Stdio::null()).stderr(Stdio::null()).spawn() { Ok(v) => v, Err(_) => { let _ = source.kill(); return; } };
    let _ = destination.wait();
    let _ = source.wait();
}

pub fn delete_item(id: &str) {
    if !valid_id(id) { return; }
    let _ = Command::new("cliphist").arg("delete").stdin(Stdio::piped()).stdout(Stdio::null()).stderr(Stdio::null())
        .spawn().and_then(|mut child| {
            if let Some(mut stdin) = child.stdin.take() { let _ = writeln!(stdin, "{id}"); }
            child.wait()
        });
}

pub fn clear() -> Result<(), Box<dyn std::error::Error>> {
    let _ = Command::new("wl-copy").args(["--clear"]).stdout(Stdio::null()).stderr(Stdio::null()).status()?;
    let _ = Command::new("cliphist").arg("wipe").stdout(Stdio::null()).stderr(Stdio::null()).status()?;
    let prefix = cache_prefix();
    for entry in fs::read_dir(std::env::temp_dir())? {
        let Ok(entry) = entry else { continue };
        if entry.file_name().to_string_lossy().starts_with(&prefix) && entry.path().extension().is_some_and(|v| v == "png") {
            let _ = fs::remove_file(entry.path());
        }
    }
    Ok(())
}
