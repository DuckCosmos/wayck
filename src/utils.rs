use std::collections::HashMap;
use std::path::PathBuf;

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

fn arquivo_uso() -> Option<PathBuf> {
    dirs::home_dir().map(|home| home.join(".local/share/wayck_uso.txt"))
}

pub fn ler_uso() -> HashMap<String, u32> {
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

pub fn registrar_uso(nome: &str) {
    let mut uso = ler_uso();
    *uso.entry(nome.to_string()).or_insert(0) += 1;

    if let Some(caminho) = arquivo_uso() {
        let texto: String = uso.iter().map(|(n, c)| format!("{n}\t{c}\n")).collect();
        let _ = std::fs::write(caminho, texto);
    }
}
