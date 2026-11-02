use std::{
    env, fs,
    io::{self, BufRead, BufReader, Write},
    os::unix::fs::PermissionsExt,
    path::{Path, PathBuf},
    process::{Command, Stdio},
    time::{SystemTime, UNIX_EPOCH},
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
    "kitty",
    "papirus-icon-theme",
];

// ---------- Idioma / Language ----------
struct T {
    no_pacman: &'static str,
    q_pkgs: &'static str,
    q_wl: &'static str,
    pkgs_ok: &'static str,
    wl_ok: &'static str,
    abort: &'static str,
    blur_info: &'static str,
    blur_warn: &'static str,
    q_blur: &'static str,
    f_wl: &'static str,
    cfg_kept: &'static str,
    build: &'static str,
    installing: &'static str,
    hypr_q: &'static str,
    hypr_backup: &'static str,
    hypr_done: &'static str,
    hypr_manual: &'static str,
    started: &'static str,
    start_failed: &'static str,
    open: &'static str,
    bind: &'static str,
    cmds: &'static str,
    c_start: &'static str,
    c_stop: &'static str,
    c_restart: &'static str,
    good: &'static str,
}

static PT: T = T {
    no_pacman: "Este instalador só suporta Arch/CachyOS (pacman). Veja a instalação manual no README.",
    q_pkgs: "Instalar os pacotes necessários com pacman? [S/n]",
    q_wl: "Instalar o WL-Paste? Necessário para a funcionalidade do Clipboard [S/n]",
    wl_ok: "Pacote WL está instalado!",
    pkgs_ok: "Pacotes instalados",
    abort: "Abortando.",
    blur_info: "Blur: deixa o fundo do launcher borrado. Mais bonito, mas usa mais GPU.",
    blur_warn: "Aviso: isso liga o blur do Hyprland inteiro (janelas translúcidas também ficam borradas).",
    q_blur: "Ativar blur? [S/n]",
    f_wl: "FALHA: Comando falhado, execute: sudo pacman -S wl-clipboard cliphist",
    cfg_kept: "Config existente mantida:",
    build: "📦 Compilando o backend em Rust...",
    installing: "📁 Instalando em",
    hypr_q: "Instalar o preset do Hyprland do Wayck em ~/.config/hypr? Ele SUBSTITUI a tua config (inclui monitor, variáveis NVIDIA e apps no autostart como OBS, Vesktop e Spotify). Um backup é feito. [s/N]",
    hypr_backup: "Backup salvo em",
    hypr_done: "Preset instalado. Reinicie o Hyprland ou rode: hyprctl reload",
    hypr_manual: "Pra iniciar o Wayck junto com o Hyprland, adicione ao teu hyprland.lua:",
    started: "✓ Wayck iniciado.",
    start_failed: "Não consegui iniciar. Rode: quickshell -c wayck",
    open: "Abrir o launcher:",
    bind: "Atalho no hyprland.lua:",
    cmds: "Comandos úteis:",
    c_start: "iniciar",
    c_stop: "parar",
    c_restart: "reiniciar (após editar QML ou config)",
    good: "Boa sorte!",
};

static EN: T = T {
    no_pacman: "This installer only supports Arch/CachyOS (pacman). See the manual installation in the README.",
    q_pkgs: "Install the required packages with pacman? [Y/n]",
    q_wl: "Install WL-Paste? Required for Clipboard functionality [Y/n]",
    wl_ok: "WL package is installed!",
    pkgs_ok: "Packages installed",
    abort: "Aborting.",
    blur_info: "Blur: blurs the launcher background. Looks better, but uses more GPU.",
    blur_warn: "Warning: this turns on Hyprland's global blur (translucent windows get blurred too).",
    q_blur: "Enable blur? [Y/n]",
    f_wl: "FAILURE: Command failed, run: sudo pacman -S wl-clipboard cliphist",
    cfg_kept: "Existing config kept:",
    build: "📦 Building the Rust backend...",
    installing: "📁 Installing to",
    hypr_q: "Install the Wayck Hyprland preset into ~/.config/hypr? It REPLACES your config (includes monitor, NVIDIA variables and autostart apps like OBS, Vesktop and Spotify). A backup is made. [y/N]",
    hypr_backup: "Backup saved to",
    hypr_done: "Preset installed. Restart Hyprland or run: hyprctl reload",
    hypr_manual: "To start Wayck with Hyprland, add this to your hyprland.lua:",
    started: "✓ Wayck started.",
    start_failed: "Could not start it. Run: quickshell -c wayck",
    open: "Open the launcher:",
    bind: "Keybind for hyprland.lua:",
    cmds: "Useful commands:",
    c_start: "start",
    c_stop: "stop",
    c_restart: "restart (after editing QML or config)",
    good: "Good luck!",
};

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
fn ask(prompt: &str, default_yes: bool) -> bool {
    print!("{prompt}");
    let _ = io::stdout().flush();
    let mut reply = String::new();
    if let Ok(tty) = fs::File::open("/dev/tty") {
        let _ = BufReader::new(tty).read_line(&mut reply);
    }
    let r = reply.trim().to_lowercase();
    if r.is_empty() {
        return default_yes;
    }
    matches!(r.as_str(), "s" | "y" | "sim" | "yes")
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

// ---------- Etapas ----------
fn install_packages(t: &T) -> Res<()> {
    if !ask(&format!("{YE}{}{RESET} ", t.q_pkgs), true) {
        return Err(t.abort.into());
    }
    let mut args = vec!["pacman", "-S", "--needed"];
    args.extend(PKGS);
    must("sudo", &args)?;
    println!("{GREEN}{}{RESET}", t.pkgs_ok);

    let instalado = Command::new("command")
        .args(["-v", "wl-paste"])
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()
        .map(|s| s.success())
        .unwrap_or(false);

    let rodando = Command::new("pgrep")
        .args(["-f", "[w]l-paste.*watch"])
        .status()
        .map(|s| s.success())
        .unwrap_or(false);

    if !instalado {
        println!("{YE}{}{RESET}", t.q_wl);
        if !ask(&format!("{YE}[S/n]{RESET} "), true) {
            return Ok(());
        }
        let status = Command::new("sudo")
            .args([
                "pacman",
                "-S",
                "--needed",
                "--noconfirm",
                "wl-clipboard",
                "cliphist",
            ])
            .status();

        if status.is_err() || !status.unwrap().success() {
            return Err(t.f_wl.into());
        }
        println!("{GREEN}{}{RESET}", t.wl_ok);
    }

    if !rodando {
        let _ = Command::new("setsid")
            .args(["wl-paste", "--type", "text", "--watch", "cliphist", "store"])
            .spawn();
        let _ = Command::new("setsid")
            .args([
                "wl-paste", "--type", "image", "--watch", "cliphist", "store",
            ])
            .spawn();
    }

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
    let blur = ask(&format!("{MAGENTA}{}{RESET} ", t.q_blur), true);
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

fn install_hypr(t: &T, root: &Path, config_home: &Path) -> Res<()> {
    let src = root.join("hypr");
    if !src.is_dir() || !have("Hyprland") {
        return Ok(());
    }
    let dst = config_home.join("hypr");

    if ask(&format!("\n{YE}{}{RESET} ", t.hypr_q), false) {
        if dst.exists() {
            let stamp = SystemTime::now().duration_since(UNIX_EPOCH)?.as_secs();
            let bak = config_home.join(format!("hypr.bak-{stamp}"));
            fs::rename(&dst, &bak)?;
            println!("{BLUE}{} {}{RESET}", t.hypr_backup, bak.display());
        }
        copy_dir(&src, &dst)?;
        println!("{GREEN}{}{RESET}", t.hypr_done);
    } else {
        println!("\n{BLUE}{}{RESET}", t.hypr_manual);
        println!("  hl.on(\"hyprland.start\", function()");
        println!("      hl.exec_cmd(\"quickshell -c wayck\")");
        println!("  end)");
    }
    Ok(())
}

fn start_shell(t: &T) {
    if !env_set("WAYLAND_DISPLAY") || !have("quickshell") {
        return;
    }

    let _ = quiet("pkill", &["-f", "quickshell -c wayck"]);

    let ok = Command::new("setsid")
        .args(["quickshell", "-c", "wayck"])
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .spawn()
        .is_ok();

    if ok {
        println!("{GREEN}{}{RESET}", t.started);
    } else {
        println!("{RED}{}{RESET}", t.start_failed);
    }
}

fn print_final(t: &T) {
    println!("\n{BLUE}{}{RESET}", t.open);
    println!("  quickshell -c wayck ipc call launcher toggle");

    println!("\n{BLUE}{}{RESET}", t.bind);
    println!(
        r#"  hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd("quickshell -c wayck ipc call launcher toggle"))"#
    );

    println!("\n{BLUE}{}{RESET}", t.cmds);
    println!(
        "  setsid quickshell -c wayck &                                 # {}",
        t.c_start
    );
    println!(
        "  pkill -f \"quickshell -c wayck\"                               # {}",
        t.c_stop
    );
    println!(
        "  pkill -f \"quickshell -c wayck\"; setsid quickshell -c wayck &   # {}",
        t.c_restart
    );

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

    install_packages(t)?;
    setup_blur(t, &cfg_dir)?;
    build_and_install(t, &root, &dest)?;
    install_hypr(t, &root, &config_home)?;
    start_shell(t);
    print_final(t);
    Ok(())
}

fn main() {
    if let Err(e) = real_main() {
        eprintln!("{RED}{e}{RESET}");
        std::process::exit(1);
    }
}
