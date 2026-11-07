use std::io::{self, Write};
use std::process::{exit, Command};
use std::time::{SystemTime, UNIX_EPOCH};

const RED: &str = "\x1b[31m";
const GREEN: &str = "\x1b[32m";
const YE: &str = "\x1b[33m";
const BLUE: &str = "\x1b[34m";
const RESET: &str = "\x1b[0m";

fn main() {
    let status = Command::new("git")
        .args(["status", "--porcelain"])
        .output()
        .expect("Falha ao executar o git.");

    if String::from_utf8_lossy(&status.stdout).trim().is_empty() {
        println!("{YE}✨ Nenhuma alteração detectada. Tudo atualizado.{RESET}");
        return;
    }

    print!("{BLUE}💬 Mensagem do commit (ou Enter para automático): {RESET}");
    let _ = io::stdout().flush();

    let mut msg = String::new();
    io::stdin().read_line(&mut msg).unwrap();
    let msg = msg.trim();

    let final_msg = if msg.is_empty() {
        let agora = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_secs();
        format!("Atualização automática - {}", agora)
    } else {
        msg.to_string()
    };

    println!("{BLUE}🚀 Enviando para o GitHub...{RESET}");

    let add = Command::new("git").args(["add", "."]).status().unwrap();
    if !add.success() {
        exit(1);
    }

    let commit = Command::new("git")
        .args(["commit", "-m", &final_msg])
        .status()
        .unwrap();
    if !commit.success() {
        exit(1);
    }

    let push = Command::new("git").args(["push"]).status().unwrap();

    if push.success() {
        println!("\n{GREEN}✅ Sucesso! Código enviado.{RESET}");
    } else {
        println!("\n{RED}❌ Falha no envio. Verifique a conexão ou a branch.{RESET}");
        exit(1);
    }
}
