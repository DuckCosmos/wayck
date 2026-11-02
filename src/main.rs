mod clipboard;
mod launcher;
mod monitor;
mod utils;

use std::io::{self, BufRead};

fn main() {
    let args: Vec<String> = std::env::args().collect();

    if args.len() > 1 {
        match args[1].as_str() {
            "--monitor" => monitor::run(),
            "--filter" => {
                let busca = if args.len() > 2 { &args[2] } else { "" };
                let res = launcher::filtrar(busca);
                if let Ok(json) = serde_json::to_string(&res) {
                    println!("{}", json);
                }
            }
            "--exec" => {
                if args.len() > 3 {
                    utils::registrar_uso(&args[2]);
                    launcher::executar(&args[3]);
                }
            }

            "--clipboard-list" => {
                let busca = if args.len() > 2 { &args[2] } else { "" };
                let res = clipboard::listar(busca);
                if let Ok(json) = serde_json::to_string(&res) {
                    println!("{}", json);
                }
            }
            "--clipboard-copy" => {
                if args.len() > 2 {
                    clipboard::copiar(&args[2]);
                }
            }

            "--clipboard-delete" => {
                if args.len() > 2 {
                    clipboard::deletar(&args[2]);
                }
            }

            _ => {}
        }
        return;
    }

    let stdin = io::stdin();
    for line in stdin.lock().lines().flatten() {
        let res = launcher::filtrar(&line);
        if let Ok(json) = serde_json::to_string(&res) {
            println!("{}", json);
        }
    }
}
