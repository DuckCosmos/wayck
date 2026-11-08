use std::error::Error;

const LOCAL_VERSION: &str = include_str!("../version.txt");

async fn remote_version() -> Result<String, Box<dyn Error>> {
    let version = reqwest::get(
        "https://raw.githubusercontent.com/DuckCosmos/wayck/main/version.txt"
    )
    .await?
    .error_for_status()?
    .text()
    .await?;

    Ok(version.trim().to_string())
}

pub async fn check_info() -> Result<(String, String, bool), Box<dyn Error>> {
    let local = LOCAL_VERSION.trim().to_string();
    let remote = remote_version().await?;

    // A newer version is represented by a changed version.txt on main.
    // Empty remote files are ignored so an unversioned repository cannot
    // accidentally advertise a blank update.
    let available = !local.is_empty()
        && !remote.is_empty()
        && remote != local;

    Ok((local, remote, available))
}

pub async fn check() -> Result<bool, Box<dyn Error>> {
    let (_, _, available) = check_info().await?;
    Ok(available)
}
