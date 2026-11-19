mod clipboard;
mod launcher;
mod monitor;
mod update;
mod utils;

use std::io::{self, BufRead};

fn emit<T: serde::Serialize>(value: &T) {
    if let Ok(json) = serde_json::to_string(value) {
        println!("{json}");
    }
}

fn run() -> Result<i32, Box<dyn std::error::Error>> {
    let args: Vec<String> = std::env::args().skip(1).collect();
    if let Some(command) = args.first().map(String::as_str) {
        let rest = &args[1..];
        match command {
            "--monitor" => monitor::run(),
            "--filter" => emit(&launcher::filter_apps(rest.first().map(String::as_str).unwrap_or(""))),
            "--exec" if rest.len() >= 2 => {
                utils::register_usage(&rest[0]);
                launcher::execute(&rest[1], &rest[0]);
            }
            "--clipboard-list" => emit(&clipboard::list_items(rest.first().map(String::as_str).unwrap_or(""))),
            "--clipboard-copy" if !rest.is_empty() => clipboard::copy_item(&rest[0]),
            "--clipboard-delete" if !rest.is_empty() => clipboard::delete_item(&rest[0]),
            "--clipboard-clear" => clipboard::clear()?,
            "--check_version" => println!("{}", update::check()?),
            "--version_info" => emit(&update::check_info()?),
            _ => {}
        }
        return Ok(0);
    }

    for line in io::stdin().lock().lines() {
        match line {
            Ok(query) => emit(&launcher::filter_apps(&query)),
            Err(error) => eprintln!("Erro no launcher: {error}"),
        }
    }
    Ok(0)
}

fn main() {
    match std::panic::catch_unwind(run) {
        Ok(Ok(code)) => std::process::exit(code),
        Ok(Err(error)) => {
            eprintln!("Wayck backend: {error}");
            std::process::exit(1);
        }
        Err(_) => std::process::exit(1),
    }
}
