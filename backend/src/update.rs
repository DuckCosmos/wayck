use serde::Serialize;
use std::fs;
use std::time::Duration;

const VERSION_URL: &str = "https://raw.githubusercontent.com/DuckCosmos/wayck/main/version.txt";

#[derive(Serialize)]
pub struct VersionInfo {
    local: String,
    remote: String,
    available: bool,
}

fn local_version() -> String {
    let path = std::env::current_exe().ok()
        .and_then(|p| p.parent().map(|p| p.join("version.txt")))
        .or_else(|| Some(std::path::PathBuf::from("version.txt")));
    path.and_then(|p| fs::read_to_string(p).ok()).unwrap_or_default().trim().to_string()
}

fn remote_version() -> Result<String, Box<dyn std::error::Error>> {
    let client = reqwest::blocking::Client::builder().timeout(Duration::from_secs(8)).build()?;
    let value = client.get(VERSION_URL).header("User-Agent", "Wayck-Updater/1.0").send()?.error_for_status()?.text()?;
    Ok(value.chars().take(256).collect::<String>().trim().to_string())
}

pub fn check_info() -> Result<VersionInfo, Box<dyn std::error::Error>> {
    let local = local_version();
    let remote = remote_version()?;
    let available = !local.is_empty() && !remote.is_empty() && remote != local;
    Ok(VersionInfo { local, remote, available })
}

pub fn check() -> Result<bool, Box<dyn std::error::Error>> {
    Ok(check_info()?.available)
}
