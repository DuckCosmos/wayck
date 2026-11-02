use serde::{Deserialize, Serialize};
use std::path::Path;
use std::process::Command;

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct ClipboardItem {
    pub id: String,
    pub content: String,
    pub is_image: bool,
    pub path: Option<String>,
}

pub fn listar(termo: &str) -> Vec<ClipboardItem> {
    let output = Command::new("cliphist")
        .arg("list")
        .output()
        .expect("Falha ao executar cliphist");

    let stdout = String::from_utf8_lossy(&output.stdout);
    let busca = termo.to_lowercase();
    let mut items = Vec::new();

    for line in stdout.lines() {
        if let Some((id, content)) = line.split_once('\t') {
            if !busca.is_empty() && !content.to_lowercase().contains(&busca) {
                continue;
            }

            let is_image = content.starts_with("[[ binary data") && content.contains("png");

            let mut path_opt = None;

            if is_image {
                let path_str = format!("/tmp/wayck_clip_{}.png", id);
                if !Path::new(&path_str).exists() {
                    let _ = Command::new("sh")
                        .arg("-c")
                        .arg(format!("cliphist decode {} > {}", id, path_str))
                        .output();
                }
                path_opt = Some(path_str);
            }

            let display_content = if is_image {
                content.to_string()
            } else {
                content.replace('\n', " ")
            };

            items.push(ClipboardItem {
                id: id.to_string(),
                content: display_content,
                is_image,
                path: path_opt,
            });

            if items.len() >= 50 {
                break;
            }
        }
    }
    items
}

pub fn copiar(id: &str) {
    let _ = Command::new("sh")
        .arg("-c")
        .arg(format!("cliphist decode {} | wl-copy", id))
        .spawn();
}

pub fn deletar(id: &str) {
    let _ = Command::new("sh")
        .arg("-c")
        .arg(format!("echo '{}' | cliphist delete", id))
        .spawn();
}
