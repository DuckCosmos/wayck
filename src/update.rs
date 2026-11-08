use std::fs;

fn parse_version(version: &str) -> Option<(u32, u32, u32)> {
    let parts: Vec<u32> = version
        .trim()
        .split(".")
        .map(|part| part.parse::<u32>().ok())
        .collect::<Option<Vec<u32>>>()?;

    if parts.len() != 3 {
        return None;
    }

    Some((parts[0], parts[1], parts[2]))
}

async fn remote_version() -> Result<String, Box<dyn std::error::Error>> {
    let version =
        reqwest::get("https://raw.githubusercontent.com/DuckCosmos/wayck/main/version.txt")
            .await?
            .error_for_status()?
            .text()
            .await?;

    Ok(version.trim().to_string())
}

fn has_update(local: &str, remote: &str) -> bool {
    match (parse_version(local), parse_version(remote)) {
        (Some(local), Some(remote)) => remote > local,
        _ => false,
    }
}

pub async fn check() -> Result<bool, Box<dyn std::error::Error>> {
    let local = fs::read_to_string(
        dirs::data_local_dir()
            .ok_or_else(|| {
                std::io::Error::new(std::io::ErrorKind::NotFound, "Directory unavailable")
            })?
            .join("wayck-src/version.txt"),
    )?;

    let remote = remote_version().await?;

    Ok(has_update(&local, &remote))
}
