#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/DuckCosmos/wayck.git"

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
SRC_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/wayck-src"
CFG_DIR="$CONFIG_HOME/wayck"
CFG="$CFG_DIR/config.json"
DEST="$CONFIG_HOME/quickshell/wayck"
SERVICE_DIR="$CONFIG_HOME/systemd/user"

RED=$'\e[31m'; GREEN=$'\e[32m'; YE=$'\e[33m'; BLUE=$'\e[34m'; MAGENTA=$'\e[35m'; RESET=$'\e[0m'

ask() {
    local prompt="$1" default="$2" reply=""
    read -rp "$prompt" reply < /dev/tty || true
    reply="${reply:-$default}"
    [[ "${reply,,}" =~ ^(s|y|sim|yes)$ ]]
}

if [[ -f "${BASH_SOURCE[0]:-}" ]]; then
    cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
fi

if ! command -v pacman >/dev/null; then
    echo "${RED}Este instalador só suporta Arch/CachyOS (pacman). Veja a instalação manual no README.${RESET}"
    exit 1
fi

# ---------- 1. Pacotes ----------
if ask "🇧🇷 ${YE}Instalar os pacotes necessários com pacman? [S/n]${RESET} | 🇺🇸 ${YE}Install required packages with pacman? [Y/n]${RESET} " s; then
    PKGS=(quickshell qt6-declarative qt6-wayland git base-devel wl-clipboard kitty papirus-icon-theme)
    command -v cargo >/dev/null || PKGS+=(rust)    # evita conflito com rustup
    sudo pacman -S --needed "${PKGS[@]}"
    echo "${GREEN}Pacotes OK | Packages OK${RESET}"
else
    echo "${RED}Abortando | Aborting.${RESET}"
    exit 1
fi

# ---------- 2. Código-fonte ----------
if [[ ! -f Cargo.toml || ! -d qml ]]; then
    if [[ -d "$SRC_DIR/.git" ]]; then
        echo "📥 Atualizando código-fonte..."
        git -C "$SRC_DIR" pull --ff-only
    else
        echo "📥 Baixando código-fonte..."
        git clone --depth 1 "$REPO_URL" "$SRC_DIR"
    fi
    cd "$SRC_DIR"
fi

# ---------- 3. Blur (só pergunta na primeira instalação) ----------
if [[ ! -f "$CFG" ]]; then
    echo
    echo "${MAGENTA}Blur: deixa o fundo do launcher borrado. Mais bonito, mas usa mais GPU.${RESET}"
    echo "${YE}Aviso: isso liga o blur do Hyprland inteiro (janelas translúcidas também ficam borradas).${RESET}"
    if ask "🇧🇷 ${MAGENTA}Ativar blur? [S/n]${RESET} | 🇺🇸 ${MAGENTA}Enable blur? [Y/n]${RESET} " s; then
        BLUR=true
    else
        BLUR=false
    fi
    mkdir -p "$CFG_DIR"
    printf '{ "blur": %s }\n' "$BLUR" > "$CFG"
else
    echo "${BLUE}Config existente mantida: $CFG${RESET}"
fi

# ---------- 4. Compilar e instalar ----------
echo "📦 Compilando backend em ${RED}Rust${RESET}..."
cargo build --release

echo "📁 ${GREEN}Instalando em $DEST${RESET}"
mkdir -p "$DEST"
rm -f "$DEST"/*.qml
cp -r qml/. "$DEST/"
install -m755 target/release/wayck-backend "$DEST/wayck-backend"

# ---------- 5. Serviço systemd ----------
echo "${GREEN}Criando serviço systemd...${RESET}"
mkdir -p "$SERVICE_DIR"

cat > "$SERVICE_DIR/wayck.service" <<'EOF'
[Unit]
Description=Wayck Launcher (Quickshell)
After=graphical-session.target
PartOf=graphical-session.target

[Service]
Type=simple
ExecStart=/usr/bin/quickshell -c wayck
Restart=on-failure
RestartSec=3

[Install]
WantedBy=graphical-session.target
EOF

systemctl --user import-environment WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP 2>/dev/null || true
systemctl --user daemon-reload
systemctl --user enable wayck.service
systemctl --user restart wayck.service

sleep 1
if systemctl --user is-active --quiet wayck.service; then
    echo "${GREEN}✓ Wayck rodando em background.${RESET}"
else
    echo "${RED}O serviço não iniciou.${RESET} Veja: journalctl --user -u wayck -n 30"
fi

# ---------- 6. Final ----------
cat <<EOF

${BLUE}Abrir o launcher | Open the launcher:${RESET}
  quickshell -c wayck ipc call launcher toggle

${BLUE}Atalho no hyprland.lua | Hyprland keybind:${RESET}
  hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd("quickshell -c wayck ipc call launcher toggle"))

${BLUE}Comandos úteis | Useful commands:${RESET}
  systemctl --user status wayck     # status
  systemctl --user restart wayck    # reiniciar (após editar QML ou config)
  systemctl --user stop wayck       # parar
  journalctl --user -u wayck -f     # logs ao vivo

${GREEN}Good Luck!${RESET}
EOF