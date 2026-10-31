use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::io::{self, BufRead};
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::sync::OnceLock;

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct AppData {
    pub nome: String,
    pub icone_path: String,
    pub exec: String,
}

static APPS: OnceLock<Vec<AppData>> = OnceLock::new();

fn pastas() -> Vec<PathBuf> {
    let mut p = vec![
        PathBuf::from("/usr/share/applications"),
        PathBuf::from("/usr/local/share/applications"),
        PathBuf::from("/var/lib/flatpak/exports/share/applications"),
    ];
    if let Some(home) = dirs::home_dir() {
        p.push(home.join(".local/share/applications"));
        p.push(home.join(".local/share/flatpak/exports/share/applications"));
    }
    p
}

fn ler_desktop(caminho: &Path) -> Option<(String, String, String)> {
    let conteudo = std::fs::read_to_string(caminho).ok()?;

    let mut nome = None;
    let mut icone_nome = String::new();
    let mut exec = None;
    let mut esconder = false;
    let mut secao_certa = false;

    for linha in conteudo.lines() {
        let linha = linha.trim();

        if linha.starts_with('[') {
            secao_certa = linha == "[Desktop Entry]";
            continue;
        }
        if !secao_certa {
            continue;
        }

        if let Some(v) = linha.strip_prefix("Name=") {
            nome = Some(v.to_string());
        } else if let Some(v) = linha.strip_prefix("Icon=") {
            icone_nome = v.to_string();
        } else if let Some(v) = linha.strip_prefix("Exec=") {
            exec = Some(v.to_string());
        } else if linha == "NoDisplay=true" || linha == "Hidden=true" {
            esconder = true;
        }
    }

    if esconder {
        return None;
    }

    let nome = nome?;
    let exec = exec?;

    let icone_path = if icone_nome.is_empty() {
        String::new()
    } else if icone_nome.starts_with('/') && Path::new(&icone_nome).exists() {
        icone_nome.clone()
    } else {
        let home = dirs::home_dir().unwrap_or_default();
        let h = home.to_string_lossy();

        let caminhos = [
            format!("/usr/share/icons/Papirus/48x48/apps/{}.svg", icone_nome),
            format!(
                "/usr/share/icons/Papirus-Dark/48x48/apps/{}.svg",
                icone_nome
            ),
            format!("/usr/share/icons/hicolor/scalable/apps/{}.svg", icone_nome),
            format!("/usr/share/icons/hicolor/256x256/apps/{}.png", icone_nome),
            format!("/usr/share/icons/hicolor/128x128/apps/{}.png", icone_nome),
            format!("/usr/share/icons/hicolor/48x48/apps/{}.png", icone_nome),
            format!("/usr/share/pixmaps/{}.png", icone_nome),
            format!("/usr/share/pixmaps/{}.svg", icone_nome),
            format!("/usr/share/pixmaps/{}.xpm", icone_nome),
            format!(
                "{}/.local/share/icons/hicolor/scalable/apps/{}.svg",
                h, icone_nome
            ),
            format!(
                "{}/.local/share/icons/hicolor/256x256/apps/{}.png",
                h, icone_nome
            ),
            format!(
                "{}/.local/share/icons/hicolor/128x128/apps/{}.png",
                h, icone_nome
            ),
            format!(
                "{}/.local/share/icons/hicolor/48x48/apps/{}.png",
                h, icone_nome
            ),
            format!(
                "{}/.local/share/icons/Papirus/48x48/apps/{}.svg",
                h, icone_nome
            ),
            format!(
                "/var/lib/flatpak/exports/share/icons/hicolor/128x128/apps/{}.png",
                icone_nome
            ),
            format!(
                "/var/lib/flatpak/exports/share/icons/hicolor/64x64/apps/{}.png",
                icone_nome
            ),
            format!(
                "/var/lib/flatpak/exports/share/icons/hicolor/scalable/apps/{}.svg",
                icone_nome
            ),
            format!(
                "{}/.local/share/flatpak/exports/share/icons/hicolor/128x128/apps/{}.png",
                h, icone_nome
            ),
            format!(
                "{}/.local/share/flatpak/exports/share/icons/hicolor/64x64/apps/{}.png",
                h, icone_nome
            ),
            format!(
                "{}/.local/share/flatpak/exports/share/icons/hicolor/scalable/apps/{}.svg",
                h, icone_nome
            ),
        ];

        let mut achado = String::new();
        for c in caminhos {
            if Path::new(&c).exists() {
                achado = c;
                break;
            }
        }

        if achado.is_empty() {
            "/usr/share/icons/Papirus/48x48/apps/terminal.svg".to_string()
        } else {
            achado
        }
    };
    Some((nome, icone_path, exec))
}

fn carregar_apps() -> Vec<AppData> {
    let mut apps: Vec<AppData> = Vec::new();

    for pasta in pastas() {
        let Ok(entradas) = std::fs::read_dir(&pasta) else {
            continue;
        };
        for entrada in entradas.flatten() {
            let caminho = entrada.path();
            if caminho.extension().and_then(|e| e.to_str()) != Some("desktop") {
                continue;
            }
            if let Some((nome, icone_path, exec)) = ler_desktop(&caminho) {
                if !apps.iter().any(|a| a.nome == nome) {
                    apps.push(AppData {
                        nome,
                        icone_path,
                        exec,
                    });
                }
            }
        }
    }

    apps.sort_by(|a, b| a.nome.to_lowercase().cmp(&b.nome.to_lowercase()));
    apps
}

fn arquivo_uso() -> Option<PathBuf> {
    dirs::home_dir().map(|home| home.join(".local/share/wayck_uso.txt"))
}

fn ler_uso() -> HashMap<String, u32> {
    let mut mapa = HashMap::new();
    if let Some(caminho) = arquivo_uso() {
        if let Ok(texto) = std::fs::read_to_string(caminho) {
            for linha in texto.lines() {
                if let Some((nome, n)) = linha.rsplit_once('\t') {
                    mapa.insert(nome.to_string(), n.parse().unwrap_or(0));
                }
            }
        }
    }
    mapa
}

pub fn calcular(texto: &str) -> Option<String> {
    let expr = texto
        .replace('x', "*")
        .replace('X', "*")
        .replace('×', "*")
        .replace('÷', "/")
        .replace(',', ".");
    let expr = expr.trim();

    if !expr.chars().any(|c| c.is_ascii_digit()) {
        return None;
    }

    let tem_operador = expr.chars().any(|c| "+-*/^()".contains(c));
    let mut val = None;

    if tem_operador {
        if let Ok(v) = meval::eval_str(expr) {
            val = Some(v);
        } else {
            let partes: Vec<&str> = expr.split(|c| "+-*/^()".contains(c)).collect();
            if let Some(primeiro) = partes.first() {
                if let Ok(v) = primeiro.trim().parse::<f64>() {
                    val = Some(v);
                }
            }
        }
    } else if let Ok(v) = expr.parse::<f64>() {
        val = Some(v);
    }

    if let Some(v) = val {
        let resultado_str = if v.fract() == 0.0 {
            format!("{}", v as i64)
        } else {
            let s = format!("{}", v);
            if texto.contains(',') {
                s.replace('.', ",")
            } else {
                s
            }
        };
        Some(resultado_str)
    } else {
        None
    }
}

pub fn registrar_uso(nome: &str) {
    let mut uso = ler_uso();
    *uso.entry(nome.to_string()).or_insert(0) += 1;

    if let Some(caminho) = arquivo_uso() {
        let texto: String = uso.iter().map(|(n, c)| format!("{n}\t{c}\n")).collect();
        let _ = std::fs::write(caminho, texto);
    }
}

pub fn filtrar(texto: &str) -> Vec<AppData> {
    let busca = texto.to_lowercase();
    let uso = ler_uso();

    let mut res: Vec<AppData> = APPS
        .get_or_init(carregar_apps)
        .iter()
        .filter(|a| a.nome.to_lowercase().contains(&busca))
        .cloned()
        .collect();

    res.sort_by(|a, b| {
        let ua = uso.get(&a.nome).unwrap_or(&0);
        let ub = uso.get(&b.nome).unwrap_or(&0);
        ub.cmp(ua)
    });

    res.truncate(15);

    if let Some(texto_res) = calcular(texto) {
        res.insert(
            0,
            AppData {
                nome: format!("{} = {}", texto.trim(), texto_res),
                icone_path: "/usr/share/icons/Papirus/48x48/apps/accessories-calculator.svg"
                    .to_string(),
                exec: format!("sh -c \"echo -n '{}' | wl-copy\"", texto_res),
            },
        );
    } else if res.is_empty() && !texto.trim().is_empty() {
        res.push(AppData {
            nome: texto.to_string(),
            icone_path: "/usr/share/icons/Papirus/48x48/apps/kitty.svg".to_string(),
            exec: format!("@term:{}", texto),
        });
    }

    res
}

fn binary_exists(name: &str) -> bool {
    std::env::var_os("PATH")
        .map(|paths| std::env::split_paths(&paths).any(|p| p.join(name).is_file()))
        .unwrap_or(false)
}

fn detect_terminal() -> String {
    if let Ok(t) = std::env::var("TERMINAL") {
        if !t.is_empty() && binary_exists(&t) {
            return t;
        }
    }

    for t in [
        "kitty",
        "alacritty",
        "foot",
        "wezterm",
        "konsole",
        "gnome-terminal",
        "kgx",
        "xterm",
    ] {
        if binary_exists(t) {
            return t.to_string();
        }
    }
    "xterm".to_string()
}

fn abrir_em_terminal(cmd: &str) {
    let terminal = detect_terminal();

    let shell_cmd = format!("{}; exec \"$SHELL\"", cmd);
    let escaped = shell_cmd.replace('\'', "'\\''");

    let full = match terminal.as_str() {
        "gnome-terminal" | "kgx" => format!("{} -- sh -c '{}'", terminal, escaped),
        "wezterm" => format!("wezterm start -- sh -c '{}'", escaped),
        _ => format!("{} -e sh -c '{}'", terminal, escaped),
    };

    let _ = Command::new("sh")
        .arg("-c")
        .arg(&full)
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .spawn();
}

pub fn abrir(exec_cmd: &str) {
    if let Some(cmd) = exec_cmd.strip_prefix("@term:") {
        abrir_em_terminal(cmd);
        return;
    }
    let cmd: Vec<&str> = exec_cmd
        .split_whitespace()
        .filter(|p| !(p.starts_with('%') && p.len() == 2))
        .collect();

    let _ = Command::new("sh")
        .arg("-c")
        .arg(cmd.join(" "))
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .spawn();
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    if args.len() > 1 {
        match args[1].as_str() {
            "--exec" => {
                if args.len() > 3 {
                    registrar_uso(&args[2]);
                    abrir(&args[3]);
                }
            }
            "--filter" => {
                let busca = if args.len() > 2 { &args[2] } else { "" };
                let res = filtrar(busca);
                if let Ok(json) = serde_json::to_string(&res) {
                    println!("{}", json);
                }
            }
            _ => {}
        }
        return;
    }

    let stdin = io::stdin();
    for line in stdin.lock().lines().flatten() {
        let res = filtrar(&line);
        if let Ok(json) = serde_json::to_string(&res) {
            println!("{}", json);
        }
    }
}
