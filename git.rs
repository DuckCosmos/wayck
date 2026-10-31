use std::{
    error::Error,
    io::{self, Write},
    process::{Command, ExitCode},
};

const RED: &str = "\x1b[31m";
const GREEN: &str = "\x1b[32m";
const YE: &str = "\x1b[33m";
const BLUE: &str = "\x1b[34m";
const RESET: &str = "\x1b[0m";

fn git(args: &[&str]) -> Result<(), Box<dyn Error>> {
    let status = Command::new("git").args(args).status()?;
    if status.success() {
        Ok(())
    } else {
        Err(format!("git {} falhou ({status})", args.join(" ")).into())
    }
}

fn ask_commit() -> Result<String, Box<dyn Error>> {
    loop {
        print!("{BLUE}Qual commit você quer enviar? {RED}");
        io::stdout().flush()?;

        let mut cmt = String::new();
        let n = io::stdin().read_line(&mut cmt)?;
        print!("{RESET}");

        if n == 0 {
            return Err("entrada encerrada (EOF)".into());
        }
        let cmt = cmt.trim();
        if !cmt.is_empty() {
            return Ok(cmt.to_string());
        }
        println!("{RED}ERRO:{RESET} {YE}O commit não deve estar vazio.{RESET}");
    }
}

fn run() -> Result<(), Box<dyn Error>> {
    println!("{GREEN}Inicialização do GitRepository{RESET}");

    git(&["add", "."])?;

    let nothing_staged = Command::new("git")
        .args(["diff", "--cached", "--quiet"])
        .status()?
        .success();
    if nothing_staged {
        println!("{YE}Nenhuma alteração para commitar.{RESET}");
        return Ok(());
    }

    let cmt = ask_commit()?;
    git(&["commit", "-m", cmt.as_str()])?;
    git(&["push"])?;

    println!("{GREEN}Arquivos enviados com sucesso ao GitHub!{RESET}");
    Ok(())
}

fn main() -> ExitCode {
    match run() {
        Ok(()) => ExitCode::SUCCESS,
        Err(e) => {
            eprintln!("{RED}{e}{RESET}");
            ExitCode::FAILURE
        }
    }
}
