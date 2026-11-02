use std::{
    env, fs,
    io::{self, BufRead, Write},
    os::unix::fs::PermissionsExt,
    path::{Path, PathBuf},
    process::{Command, ExitStatus, Stdio},
    time::{SystemTime, UNIX_EPOCH},
};

use crossterm::{
    cursor,
    event::{self, Event, KeyCode},
    execute,
    terminal::{self, ClearType},
};

use serde_json::Value;

type Res<T> = Result<T, Box<dyn std::error::Error>>;

const RED: &str = "\x1b[31m";
const GREEN: &str = "\x1b[32m";
const YE: &str = "\x1b[33m";
const BLUE: &str = "\x1b[34m";
const MAGENTA: &str = "\x1b[35m";
const RESET: &str = "\x1b[0m";

const REQUIRED_PKGS: &[&str] = &[
    "quickshell",
    "qt6-declarative",
    "qt6-wayland",
    "git",
    "base-devel",
    "kitty",
    "papirus-icon-theme",
    "wl-clipboard",
    "cliphist",
    "micro",
];

const PERSONAL_REPO_PKGS: &[&str] = &[
    "obs-studio",
    "micro",
    "zsh",
    "steam",
    "heroic-games-launcher",
    "lutris",
];

const PERSONAL_AUR_PKGS: &[&str] = &["vesktop", "vscodium-bin", "brave-bin"];

struct T {
    title: &'static str,
    menu_help: &'static str,
    menu_required: &'static str,
    menu_blur: &'static str,
    menu_apps: &'static str,
    menu_hypr: &'static str,
    menu_build: &'static str,
    menu_confirm: &'static str,
    no_pacman: &'static str,
    abort: &'static str,
    pkgs_installing: &'static str,
    pkgs_ok: &'static str,
    blur_info: &'static str,
    blur_warn: &'static str,
    q_blur: &'static str,
    cfg_kept: &'static str,
    invalid_config: &'static str,
    build: &'static str,
    installing: &'static str,
    build_failed: &'static str,
    hypr_q: &'static str,
    hypr_backup: &'static str,
    hypr_done: &'static str,
    hypr_missing: &'static str,
    aur_installing: &'static str,
    aur_already_installed: &'static str,
    aur_clone_failed: &'static str,
    aur_build_failed: &'static str,
    aur_install_failed: &'static str,
    aur_installed: &'static str,
    personal_installing: &'static str,
    personal_install_failed: &'static str,
    zsh_changed: &'static str,
    zsh_change_failed: &'static str,
    steam_note: &'static str,
    final_title: &'static str,
    final_reboot: &'static str,
    final_exec: &'static str,
    good: &'static str,
}

static PT: T = T {
    title: "WAYCK INSTALLER",
    menu_help: "Use as setas para navegar, ESPAÇO para selecionar e ENTER para continuar. ESC para sair.",
    menu_required: "Instalar pacotes necessários",
    menu_blur: "Configurar blur",
    menu_apps: "Instalar meus aplicativos",
    menu_hypr: "Instalar configurações do Hyprland",
    menu_build: "Compilar e instalar Wayck",
    menu_confirm: "ENTER: continuar | ESPAÇO: selecionar | ESC: sair",
    no_pacman: "Este instalador só suporta Arch Linux e derivados que utilizam pacman.",
    abort: "Instalação cancelada.",
    pkgs_installing: "Instalando os pacotes necessários...",
    pkgs_ok: "Pacotes necessários instalados.",
    blur_info: "Blur: aplica desfoque ao fundo do launcher.",
    blur_warn: "Aviso: o blur também pode afetar outras janelas translúcidas do Hyprland.",
    q_blur: "Ativar blur? [S/n]",
    cfg_kept: "Configuração atualizada:",
    invalid_config: "O config.json existente não contém um objeto JSON válido.",
    build: "Compilando o backend em Rust...",
    installing: "Instalando em",
    build_failed: "Falha ao compilar o backend.",
    hypr_q: "Instalar o preset do Wayck em ~/.config/hypr? Isso substitui a configuração atual. Um backup será criado. [s/N]",
    hypr_backup: "BACKUP SALVO EM",
    hypr_done: "Configuração do Hyprland instalada.",
    hypr_missing: "Hyprland não encontrado ou pasta hypr/ ausente. Pulando configuração.",
    aur_installing: "Instalando {}...",
    aur_already_installed: "{} já está instalado. Pulando.",
    aur_clone_failed: "Falha ao baixar o repositório AUR.",
    aur_build_failed: "Falha ao compilar ou instalar um pacote AUR.",
    aur_install_failed: "O helper AUR não foi instalado corretamente.",
    aur_installed: "{} instalado com sucesso.",
    personal_installing: "Instalando aplicativos pessoais...",
    personal_install_failed: "Falha ao instalar os aplicativos pessoais.",
    zsh_changed: "Zsh configurado como shell padrão. A alteração vale no próximo login.",
    zsh_change_failed: "Não foi possível alterar o shell padrão para Zsh.",
    steam_note: "O Steam pode exigir que o repositório multilib esteja habilitado no pacman.conf.",
    final_title: "INSTALAÇÃO CONCLUÍDA",
    final_reboot: "REINICIE O COMPUTADOR. ESTA ETAPA É OBRIGATÓRIA.",
    final_exec: "O Wayck será iniciado pelo seu exec.lua após a reinicialização.",
    good: "Obrigado por instalar o Wayck.",
};

static EN: T = T {
    title: "WAYCK INSTALLER",
    menu_help: "Use the arrow keys to navigate, SPACE to select and ENTER to continue. ESC to exit.",
    menu_required: "Install required packages",
    menu_blur: "Configure blur",
    menu_apps: "Install my applications",
    menu_hypr: "Install Hyprland configuration",
    menu_build: "Build and install Wayck",
    menu_confirm: "ENTER: continue | SPACE: select | ESC: exit",
    no_pacman: "This installer only supports Arch Linux and pacman-based distributions.",
    abort: "Installation cancelled.",
    pkgs_installing: "Installing required packages...",
    pkgs_ok: "Required packages installed.",
    blur_info: "Blur: applies background blur to the launcher.",
    blur_warn: "Warning: blur may also affect other translucent Hyprland windows.",
    q_blur: "Enable blur? [Y/n]",
    cfg_kept: "Configuration updated:",
    invalid_config: "The existing config.json does not contain a valid JSON object.",
    build: "Building the Rust backend...",
    installing: "Installing to",
    build_failed: "Failed to build the backend.",
    hypr_q: "Install the Wayck preset into ~/.config/hypr? This replaces your current configuration. A backup will be created. [y/N]",
    hypr_backup: "BACKUP SAVED TO",
    hypr_done: "Hyprland configuration installed.",
    hypr_missing: "Hyprland not found or hypr/ directory missing. Skipping configuration.",
    aur_installing: "Installing {}...",
    aur_already_installed: "{} is already installed. Skipping.",
    aur_clone_failed: "Failed to clone the AUR repository.",
    aur_build_failed: "Failed to build or install an AUR package.",
    aur_install_failed: "The AUR helper was not installed correctly.",
    aur_installed: "{} installed successfully.",
    personal_installing: "Installing personal applications...",
    personal_install_failed: "Failed to install personal applications.",
    zsh_changed: "Zsh set as the default shell. The change takes effect at the next login.",
    zsh_change_failed: "Could not change the default shell to Zsh.",
    steam_note: "Steam may require the multilib repository to be enabled in pacman.conf.",
    final_title: "INSTALLATION COMPLETED",
    final_reboot: "REBOOT YOUR COMPUTER. THIS STEP IS REQUIRED.",
    final_exec: "Wayck will be started by your exec.lua after reboot.",
    good: "Thank you for installing Wayck.",
};

struct MenuOption {
    label: String,
    selected: bool,
}

fn pick_lang() -> &'static T {
    let mut code = String::new();
    let mut args = env::args().skip(1);

    while let Some(arg) = args.next() {
        if arg == "--lang" {
            code = args.next().unwrap_or_default();
        } else if let Some(value) = arg.strip_prefix("--lang=") {
            code = value.to_string();
        }
    }

    if code.is_empty() {
        code = ["WAYCK_LANG", "LANG"]
            .iter()
            .filter_map(|key| env::var(key).ok())
            .find(|value| !value.is_empty())
            .unwrap_or_default();
    }

    if code.to_lowercase().starts_with("pt") {
        &PT
    } else {
        &EN
    }
}

fn ask(prompt: &str, default_yes: bool) -> bool {
    print!("{prompt}");
    let _ = io::stdout().flush();

    let mut reply = String::new();

    if let Ok(tty) = fs::File::open("/dev/tty") {
        let _ = io::BufReader::new(tty).read_line(&mut reply);
    }

    let reply = reply.trim().to_lowercase();

    if reply.is_empty() {
        return default_yes;
    }

    matches!(reply.as_str(), "s" | "y" | "sim" | "yes")
}

fn must_status(status: ExitStatus, message: &str) -> Res<()> {
    if status.success() {
        Ok(())
    } else {
        Err(message.into())
    }
}

fn must(cmd: &str, args: &[&str], message: &str) -> Res<()> {
    let status = Command::new(cmd).args(args).status()?;
    must_status(status, message)
}

#[allow(dead_code)]
fn quiet(cmd: &str, args: &[&str]) -> bool {
    Command::new(cmd)
        .args(args)
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()
        .map(|status| status.success())
        .unwrap_or(false)
}

fn have(bin: &str) -> bool {
    env::var_os("PATH")
        .map(|path| env::split_paths(&path).any(|dir| dir.join(bin).is_file()))
        .unwrap_or(false)
}

fn copy_dir(src: &Path, dst: &Path) -> io::Result<()> {
    fs::create_dir_all(dst)?;

    for entry in fs::read_dir(src)? {
        let entry = entry?;
        let source = entry.path();
        let target = dst.join(entry.file_name());
        let file_type = entry.file_type()?;

        if file_type.is_dir() {
            copy_dir(&source, &target)?;
        } else if file_type.is_file() {
            fs::copy(&source, &target)?;
        }
    }

    Ok(())
}

fn interactive_menu(t: &T, options: &mut [MenuOption]) -> Res<bool> {
    let mut stdout = io::stdout();
    let mut cursor_index = 0;

    terminal::enable_raw_mode()?;
    execute!(stdout, cursor::Hide)?;

    let result = loop {
        execute!(
            stdout,
            terminal::Clear(ClearType::All),
            cursor::MoveTo(0, 0)
        )?;

        println!("{BLUE}========================================{RESET}");
        println!("{GREEN}{}{RESET}", t.title);
        println!("{BLUE}========================================{RESET}\n");

        println!("{}\n", t.menu_help);

        for (index, option) in options.iter().enumerate() {
            let pointer = if index == cursor_index { ">" } else { " " };
            let checkbox = if option.selected { "x" } else { " " };

            if index == cursor_index {
                println!("{GREEN}{} [{}] {}{RESET}", pointer, checkbox, option.label);
            } else {
                println!("{} [{}] {}", pointer, checkbox, option.label);
            }
        }

        println!("\n{YE}{}{RESET}", t.menu_confirm);
        stdout.flush()?;

        match event::read()? {
            Event::Key(key) => match key.code {
                KeyCode::Up => {
                    cursor_index = cursor_index.saturating_sub(1);
                }
                KeyCode::Down => {
                    if cursor_index + 1 < options.len() {
                        cursor_index += 1;
                    }
                }
                KeyCode::Char(' ') => {
                    options[cursor_index].selected = !options[cursor_index].selected;
                }
                KeyCode::Enter => break true,
                KeyCode::Esc => break false,
                _ => {}
            },
            _ => {}
        }
    };

    execute!(stdout, cursor::Show)?;
    terminal::disable_raw_mode()?;

    println!();

    Ok(result)
}

fn install_packages(t: &T) -> Res<()> {
    println!("{BLUE}{}{RESET}", t.pkgs_installing);

    let mut args = vec!["-S", "--needed"];
    args.extend(REQUIRED_PKGS.iter().copied());

    must("sudo", &args, t.personal_install_failed)?;

    println!("{GREEN}{}{RESET}", t.pkgs_ok);

    Ok(())
}

fn setup_blur(t: &T, cfg_dir: &Path, enabled: bool) -> Res<()> {
    let cfg = cfg_dir.join("config.json");

    println!("\n{MAGENTA}{}{RESET}", t.blur_info);
    println!("{YE}{}{RESET}", t.blur_warn);

    let mut json = if cfg.exists() {
        let content = fs::read_to_string(&cfg)?;
        let parsed: Value = serde_json::from_str(&content).map_err(|_| t.invalid_config)?;

        if !parsed.is_object() {
            return Err(t.invalid_config.into());
        }

        parsed
    } else {
        Value::Object(serde_json::Map::new())
    };

    let blur = ask(&format!("{MAGENTA}{} {RESET}", t.q_blur), enabled);

    json["blur"] = Value::Bool(blur);

    fs::create_dir_all(cfg_dir)?;
    fs::write(&cfg, format!("{}\n", serde_json::to_string_pretty(&json)?))?;

    println!("{GREEN}{} {}{RESET}", t.cfg_kept, cfg.display());

    Ok(())
}

fn install_aur_helpers(t: &T) -> Res<()> {
    let helpers = [
        ("yay", "https://aur.archlinux.org/yay.git"),
        ("paru", "https://aur.archlinux.org/paru.git"),
    ];

    for (name, repository) in helpers {
        if have(name) {
            println!(
                "{GREEN}{}{RESET}",
                t.aur_already_installed.replace("{}", name)
            );
            continue;
        }

        println!("{BLUE}{}{RESET}", t.aur_installing.replace("{}", name));

        let build_dir = env::temp_dir().join(format!("wayck-{}", name));

        if build_dir.exists() {
            fs::remove_dir_all(&build_dir)?;
        }

        let clone_status = Command::new("git")
            .args(["clone", repository])
            .arg(&build_dir)
            .status()?;

        must_status(clone_status, t.aur_clone_failed)?;

        let build_status = Command::new("makepkg")
            .args(["-si", "--needed", "--noconfirm"])
            .current_dir(&build_dir)
            .status()?;

        let build_result = must_status(build_status, t.aur_build_failed);

        let _ = fs::remove_dir_all(&build_dir);

        build_result?;

        if !have(name) {
            return Err(t.aur_install_failed.into());
        }

        println!("{GREEN}{}{RESET}", t.aur_installed.replace("{}", name));
    }

    Ok(())
}

fn install_personal_apps(t: &T) -> Res<()> {
    println!("\n{BLUE}{}{RESET}", t.personal_installing);
    println!("{YE}{}{RESET}", t.steam_note);

    install_aur_helpers(t)?;

    let mut repo_args = vec!["-S", "--needed"];
    repo_args.extend(PERSONAL_REPO_PKGS.iter().copied());

    must("sudo", &repo_args, t.personal_install_failed)?;

    let helper = if have("paru") {
        "paru"
    } else if have("yay") {
        "yay"
    } else {
        return Err(t.aur_install_failed.into());
    };

    let mut aur_args = vec!["-S", "--needed"];
    aur_args.extend(PERSONAL_AUR_PKGS.iter().copied());

    must(helper, &aur_args, t.personal_install_failed)?;

    if have("zsh") {
        let current_shell = env::var("SHELL").unwrap_or_default();

        if current_shell != "/usr/bin/zsh" {
            must("chsh", &["-s", "/usr/bin/zsh"], t.zsh_change_failed)?;
        }

        println!("{GREEN}{}{RESET}", t.zsh_changed);
    }

    Ok(())
}

fn build_and_install(t: &T, root: &Path, dest: &Path) -> Res<()> {
    println!("\n{BLUE}{}{RESET}", t.build);

    let status = Command::new("cargo")
        .args(["build", "--release", "--bin", "wayck-backend"])
        .current_dir(root)
        .status()?;

    must_status(status, t.build_failed)?;

    println!("{GREEN}{} {}{RESET}", t.installing, dest.display());

    fs::create_dir_all(dest)?;

    for entry in fs::read_dir(dest)? {
        let path = entry?.path();

        if path.is_file() && path.extension().is_some_and(|extension| extension == "qml") {
            fs::remove_file(path)?;
        }
    }

    copy_dir(&root.join("qml"), dest)?;

    let binary = dest.join("wayck-backend");
    let _ = fs::remove_file(&binary);

    fs::copy(root.join("target/release/wayck-backend"), &binary)?;

    fs::set_permissions(&binary, fs::Permissions::from_mode(0o755))?;

    Ok(())
}

fn install_hypr(t: &T, root: &Path, config_home: &Path) -> Res<()> {
    let source = root.join("hypr");

    if !source.is_dir() || !have("Hyprland") {
        println!("{YE}{}{RESET}", t.hypr_missing);
        return Ok(());
    }

    let destination = config_home.join("hypr");

    if !ask(&format!("\n{YE}{} {RESET}", t.hypr_q), false) {
        return Ok(());
    }

    if fs::symlink_metadata(&destination).is_ok() {
        let stamp = SystemTime::now().duration_since(UNIX_EPOCH)?.as_secs();

        let backup = config_home.join(format!("hypr.backup-{}", stamp));

        fs::rename(&destination, &backup)?;

        println!("{GREEN}{}: {}{RESET}", t.hypr_backup, backup.display());
    }

    copy_dir(&source, &destination)?;

    println!("{GREEN}{}{RESET}", t.hypr_done);

    Ok(())
}

fn print_final(t: &T) {
    println!("\n{GREEN}========================================{RESET}");
    println!("{GREEN}{}{RESET}", t.final_title);
    println!("{GREEN}========================================{RESET}");

    println!("\n{BLUE}{}{RESET}", t.final_exec);

    println!("\n{BLUE}Useful commands:");
    println!("  quickshell -c wayck");
    println!("  quickshell -c wayck ipc call launcher toggle");
    println!("  pkill -f \"quickshell -c wayck\"");

    println!("\n{GREEN}{}{RESET}", t.good);

    println!("\n{RED}========================================{RESET}");
    println!("{RED}{}{RESET}", t.final_reboot);
    println!("{RED}========================================{RESET}");
}

fn real_main() -> Res<()> {
    let t = pick_lang();

    if !have("pacman") {
        return Err(t.no_pacman.into());
    }

    let root = PathBuf::from(env!("CARGO_MANIFEST_DIR"));

    let home = PathBuf::from(env::var("HOME")?);

    let config_home = env::var_os("XDG_CONFIG_HOME")
        .filter(|value| !value.is_empty())
        .map(PathBuf::from)
        .unwrap_or_else(|| home.join(".config"));

    let cfg_dir = config_home.join("wayck");
    let destination = config_home.join("quickshell/wayck");

    let mut options = vec![
        MenuOption {
            label: t.menu_required.into(),
            selected: true,
        },
        MenuOption {
            label: t.menu_blur.into(),
            selected: true,
        },
        MenuOption {
            label: t.menu_apps.into(),
            selected: false,
        },
        MenuOption {
            label: t.menu_hypr.into(),
            selected: false,
        },
        MenuOption {
            label: t.menu_build.into(),
            selected: true,
        },
    ];

    if !interactive_menu(t, &mut options)? {
        return Err(t.abort.into());
    }

    if options[0].selected {
        install_packages(t)?;
    }

    if options[2].selected {
        install_personal_apps(t)?;
    }

    if options[1].selected {
        setup_blur(t, &cfg_dir, true)?;
    }

    if options[3].selected {
        install_hypr(t, &root, &config_home)?;
    }

    if options[4].selected {
        build_and_install(t, &root, &destination)?;
    }

    print_final(t);

    Ok(())
}

fn main() {
    if let Err(error) = real_main() {
        eprintln!("\n{RED}{}{RESET}", error);
        std::process::exit(1);
    }
}
