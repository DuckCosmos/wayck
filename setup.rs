use std::{
    env, fs,
    io::{self, BufRead, BufReader, Write},
    os::unix::fs::PermissionsExt,
    path::{Path, PathBuf},
    process::{Command, Stdio},
    thread::sleep,
    time::Duration,
};

type Res<T> = Result<T, Box<dyn std::error::Error>>;

const RED: &str = "\x1b[31m";
const GREEN: &str = "\x1b[32m";
const YE: &str = "\x1b[33m";
const BLUE: &str = "\x1b[34m";
const MAGENTA: &str = "\x1b[35m";
const RESET: &str = "\x1b[0m";

const PKGS: &[&str] = &[
    "quickshell",
    "qt6-declarative",
    "qt6-wayland",
    "git",
    "base-devel",
    "wl-clipboard",
    "kitty",
    "papirus-icon-theme",
];

const SERVICE_UNIT: &str = "[Unit]
Description=Wayck Launcher (Quickshell)
After=graphical-session.target
PartOf=graphical-session.target

[Service]
Type=simple
ExecStart=/usr/bin/quickshell -c wayck
KillMode=process
Restart=on-failure
RestartSec=3

[Install]
WantedBy=graphical-session.target
";

// ---------- Idioma / Language ----------
struct T {
    no_pacman: &'static str,
    q_pkgs: &'static str,
    pkgs_ok: &'static str,
    abort: &'static str,
    blur_info: &'static str,
    blur_warn: &'static str,
    q_blur: &'static str,
    cfg_kept: &'static str,
    build: &'static str,
    installing: &'static str,
    service: &'static str,
    running: &'static str,
    failed: &'static str,
    see_logs: &'static str,
    auto_ok: &'static str,
    auto_warn: &'static str,
    auto_q: &'static str,
    yn: &'static str,
    auto_added: &'static str,
    auto_have: &'static str,
    auto_manual: &'static str,
    open: &'static str,
    bind: &'static str,
    cmds: &'static str,
    c_status: &'static str,
    c_restart: &'static str,
    c_stop: &'static str,
    c_logs: &'static str,
    good: &'static str,
}

static PT: T = T {
    no_pacman:
        "Este instalador só suporta Arch/CachyOS (pacman). Veja a instalação manual no README.",
    q_pkgs: "Instalar os pacotes necessários com pacman? [S/n]",
    pkgs_ok: "Pacotes instalados",
    abort: "Abortando.",
    blur_info: "Blur: deixa o fundo do launcher borrado. Mais bonito, mas usa mais GPU.",
    blur_warn:
        "Aviso: isso liga o blur do Hyprland inteiro (janelas translúcidas também ficam borradas).",
    q_blur: "Ativar blur? [S/n]",
    cfg_kept: "Config existente mantida:",
    build: "📦 Compilando o backend em Rust...",
    installing: "📁 Instalando em",
    service: "Criando serviço systemd...",
    running: "✓ Wayck rodando em background.",
    failed: "O serviço não iniciou.",
    see_logs: "Veja:",
    auto_ok: "Autostart OK (graphical-session.target ativo)",
    auto_warn: "graphical-session.target não está ativo: o Wayck não vai subir sozinho no boot.",
    auto_q: "Adicionar em",
    yn: "[S/n]",
    auto_added: "Adicionado.",
    auto_have: "Autostart já configurado em",
    auto_manual: "Coloque no autostart do seu compositor:",
    open: "Abrir o launcher:",
    bind: "Atalho no hyprland.lua:",
    cmds: "Comandos úteis:",
    c_status: "status",
    c_restart: "reiniciar (após editar QML ou config)",
    c_stop: "parar",
    c_logs: "logs ao vivo",
    good: "Boa sorte!",
};

static EN: T = T {
    no_pacman: "This installer only supports Arch/CachyOS (pacman). See the manual installation in the README.",
    q_pkgs: "Install the required packages with pacman? [Y/n]",
    pkgs_ok: "Packages installed",
    abort: "Aborting.",
    blur_info: "Blur: blurs the launcher background. Looks better, but uses more GPU.",
    blur_warn: "Warning: this turns on Hyprland's global blur (translucent windows get blurred too).",
    q_blur: "Enable blur? [Y/n]",
    cfg_kept: "Existing config kept:",
    build: "📦 Building the Rust backend...",
    installing: "📁 Installing to",
    service: "Creating systemd service...",
    running: "✓ Wayck is running in the background.",
    failed: "The service did not start.",
    see_logs: "See:",
    auto_ok: "Autostart OK (graphical-session.target is active)",
    auto_warn: "graphical-session.target is not active: Wayck won't start on boot by itself.",
    auto_q: "Add to",
    yn: "[Y/n]",
    auto_added: "Added.",
    auto_have: "Autostart already configured in",
    auto_manual: "Put this in your compositor's autostart:",
    open: "Open the launcher:",
    bind: "Keybind for hyprland.lua:",
    cmds: "Useful commands:",
    c_status: "status",
    c_restart: "restart (after editing QML or config)",
    c_stop: "stop",
    c_logs: "live logs",
    good: "Good luck!",
};

/// --lang xx / --lang=xx > $WAYCK_LANG > $LANG > en
fn pick_lang() -> &'static T {
    let mut code = String::new();
    let mut args = env::args().skip(1);
    while let Some(a) = args.next() {
        if a == "--lang" {
            code = args.next().unwrap_or_default();
        } else if let Some(v) = a.strip_prefix("--lang=") {
            code = v.to_string();
        }
    }
    if code.is_empty() {
        code = ["WAYCK_LANG", "LANG"]
            .iter()
            .filter_map(|k| env::var(k).ok())
            .find(|v| !v.is_empty())
            .unwrap_or_default();
    }
    if code.to_lowercase().starts_with("pt") {
        &PT
    } else {
        &EN
    }
}

// ---------- Helpers ----------
fn ask(prompt: &str) -> bool {
    print!("{prompt}");
    let _ = io::stdout().flush();
    let mut reply = String::new();
    if let Ok(tty) = fs::File::open("/dev/tty") {
        let _ = BufReader::new(tty).read_line(&mut reply);
    }
    let r = reply.trim().to_lowercase();
    r.is_empty() || matches!(r.as_str(), "s" | "y" | "sim" | "yes")
}

fn must(cmd: &str, args: &[&str]) -> Res<()> {
    let status = Command::new(cmd).args(args).status()?;
    if status.success() {
        Ok(())
    } else {
        Err(format!("`{cmd} {}` failed ({status})", args.join(" ")).into())
    }
}

fn quiet(cmd: &str, args: &[&str]) -> bool {
    Command::new(cmd)
        .args(args)
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()
        .map(|s| s.success())
        .unwrap_or(false)
}

fn have(bin: &str) -> bool {
    env::var_os("PATH")
        .map(|p| env::split_paths(&p).any(|d| d.join(bin).is_file()))
        .unwrap_or(false)
}

fn env_set(key: &str) -> bool {
    env::var_os(key).is_some_and(|v| !v.is_empty())
}

fn copy_dir(src: &Path, dst: &Path) -> io::Result<()> {
    fs::create_dir_all(dst)?;
    for entry in fs::read_dir(src)? {
        let entry = entry?;
        let to = dst.join(entry.file_name());
        if entry.file_type()?.is_dir() {
            copy_dir(&entry.path(), &to)?;
        } else {
            fs::copy(entry.path(), to)?;
        }
    }
    Ok(())
}

fn install_packages(t: &T) -> Res<()> {
    if !ask(&format!("{YE}{}{RESET} ", t.q_pkgs)) {
        return Err(t.abort.into());
    }
    let mut args = vec!["pacman", "-S", "--needed"];
    args.extend(PKGS);
    must("sudo", &args)?;
    println!("{GREEN}{}{RESET}", t.pkgs_ok);
    Ok(())
}

fn setup_blur(t: &T, cfg_dir: &Path) -> Res<()> {
    let cfg = cfg_dir.join("config.json");
    if cfg.exists() {
        println!("{BLUE}{} {}{RESET}", t.cfg_kept, cfg.display());
        return Ok(());
    }
    println!("\n{MAGENTA}{}{RESET}", t.blur_info);
    println!("{YE}{}{RESET}", t.blur_warn);
    let blur = ask(&format!("{MAGENTA}{}{RESET} ", t.q_blur));
    fs::create_dir_all(cfg_dir)?;
    fs::write(&cfg, format!("{{ \"blur\": {blur} }}\n"))?;
    Ok(())
}

fn build_and_install(t: &T, root: &Path, dest: &Path) -> Res<()> {
    println!("{}", t.build);
    let status = Command::new("cargo")
        .args(["build", "--release", "--bin", "wayck-backend"])
        .current_dir(root)
        .status()?;
    if !status.success() {
        return Err("cargo build failed".into());
    }

    println!("{GREEN}{} {}{RESET}", t.installing, dest.display());
    fs::create_dir_all(dest)?;

    for entry in fs::read_dir(dest)? {
        let p = entry?.path();
        if p.is_file() && p.extension().is_some_and(|x| x == "qml") {
            fs::remove_file(p)?;
        }
    }
    copy_dir(&root.join("qml"), dest)?;

    let bin = dest.join("wayck-backend");
    let _ = fs::remove_file(&bin);
    fs::copy(root.join("target/release/wayck-backend"), &bin)?;
    fs::set_permissions(&bin, fs::Permissions::from_mode(0o755))?;
    Ok(())
}

fn install_service(t: &T, service_dir: &Path) -> Res<()> {
    println!("{GREEN}{}{RESET}", t.service);
    fs::create_dir_all(service_dir)?;
    fs::write(service_dir.join("wayck.service"), SERVICE_UNIT)?;

    let _ = quiet(
        "systemctl",
        &[
            "--user",
            "import-environment",
            "WAYLAND_DISPLAY",
            "HYPRLAND_INSTANCE_SIGNATURE",
            "XDG_CURRENT_DESKTOP",
        ],
    );
    must("systemctl", &["--user", "daemon-reload"])?;
    must("systemctl", &["--user", "enable", "wayck.service"])?;
    must("systemctl", &["--user", "restart", "wayck.service"])?;

    sleep(Duration::from_secs(1));
    if quiet(
        "systemctl",
        &["--user", "is-active", "--quiet", "wayck.service"],
    ) {
        println!("{GREEN}{}{RESET}", t.running);
    } else {
        println!(
            "{RED}{}{RESET} {} journalctl --user -u wayck -n 30",
            t.failed, t.see_logs
        );
    }
    Ok(())
}

fn setup_autostart(t: &T, config_home: &Path) -> Res<()> {
    if !env_set("WAYLAND_DISPLAY") {
        return Ok(());
    }
    if quiet(
        "systemctl",
        &["--user", "is-active", "--quiet", "graphical-session.target"],
    ) {
        println!("{GREEN}{}{RESET}", t.auto_ok);
        return Ok(());
    }

    let mut vars = vec!["WAYLAND_DISPLAY", "XDG_CURRENT_DESKTOP"];
    for v in ["HYPRLAND_INSTANCE_SIGNATURE", "SWAYSOCK", "NIRI_SOCKET"] {
        if env_set(v) {
            vars.push(v);
        }
    }

    let cmd = format!(
        "dbus-update-activation-environment --systemd {} && systemctl --user start wayck.service",
        vars.join(" ")
    );

    let hypr = config_home.join("hypr/hyprland.conf");
    let sway = config_home.join("sway/config");
    let target: Option<(PathBuf, String)> =
        if env_set("HYPRLAND_INSTANCE_SIGNATURE") && hypr.is_file() {
            Some((hypr, format!("exec-once = {cmd}")))
        } else if env_set("SWAYSOCK") && sway.is_file() {
            Some((sway, format!("exec {cmd}")))
        } else {
            None
        };

    println!("\n{YE}{}{RESET}", t.auto_warn);

    match target {
        Some((file, line)) => {
            if fs::read_to_string(&file)?.contains("systemctl --user start wayck") {
                println!("{GREEN}{} {}{RESET}", t.auto_have, file.display());
                return Ok(());
            }
            println!("  {line}");
            if ask(&format!(
                "{YE}{} {}? {}{RESET} ",
                t.auto_q,
                file.display(),
                t.yn
            )) {
                let mut f = fs::OpenOptions::new().append(true).open(&file)?;
                writeln!(f, "\n# wayck autostart\n{line}")?;
                println!("{GREEN}{}{RESET}", t.auto_added);
            }
        }
        None => {
            println!("  {}", t.auto_manual);
            println!("  {cmd}");
        }
    }
    Ok(())
}

fn print_final(t: &T) {
    println!("\n{BLUE}{}{RESET}", t.open);
    println!("  quickshell -c wayck ipc call launcher toggle");

    println!("\n{BLUE}{}{RESET}", t.bind);
    println!(
        r#"  hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd("quickshell -c wayck ipc call launcher toggle"))"#
    );

    println!("\n{BLUE}{}{RESET}", t.cmds);
    println!("  systemctl --user status wayck     # {}", t.c_status);
    println!("  systemctl --user restart wayck    # {}", t.c_restart);
    println!("  systemctl --user stop wayck       # {}", t.c_stop);
    println!("  journalctl --user -u wayck -f     # {}", t.c_logs);

    println!("\n{GREEN}{}{RESET}", t.good);
}

fn real_main() -> Res<()> {
    let t = pick_lang();

    if !have("pacman") {
        return Err(t.no_pacman.into());
    }

    let root = PathBuf::from(env!("CARGO_MANIFEST_DIR"));

    let home = PathBuf::from(env::var("HOME")?);
    let config_home = env::var_os("XDG_CONFIG_HOME")
        .filter(|v| !v.is_empty())
        .map(PathBuf::from)
        .unwrap_or_else(|| home.join(".config"));

    let cfg_dir = config_home.join("wayck");
    let dest = config_home.join("quickshell/wayck");
    let service_dir = config_home.join("systemd/user");

    install_packages(t)?;
    setup_blur(t, &cfg_dir)?;
    build_and_install(t, &root, &dest)?;
    install_service(t, &service_dir)?;
    setup_autostart(t, &config_home)?;
    print_final(t);
    Ok(())
}

fn main() {
    if let Err(e) = real_main() {
        eprintln!("{RED}{e}{RESET}");
        std::process::exit(1);
    }
}
