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

# ---------- Idioma / Language ----------
LANG_CODE=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --lang)   LANG_CODE="${2:-}"; shift 2 || break ;;
        --lang=*) LANG_CODE="${1#--lang=}"; shift ;;
        *)        shift ;;
    esac
done
LANG_CODE="${LANG_CODE:-${WAYCK_LANG:-${LANG:-en}}}"

case "${LANG_CODE,,}" in
    pt*) L=pt ;;
    *)   L=en ;;
esac

if [[ "$L" == pt ]]; then
    T_NO_PACMAN="Este instalador só suporta Arch/CachyOS (pacman). Veja a instalação manual no README."
    T_Q_PKGS="Instalar os pacotes necessários com pacman? [S/n]"
    T_PKGS_OK="Pacotes instalados"
    T_ABORT="Abortando."
    T_SRC_UPDATE="📥 Atualizando código-fonte..."
    T_SRC_DOWNLOAD="📥 Baixando código-fonte..."
    T_BLUR_INFO="Blur: deixa o fundo do launcher borrado. Mais bonito, mas usa mais GPU."
    T_BLUR_WARN="Aviso: isso liga o blur do Hyprland inteiro (janelas translúcidas também ficam borradas)."
    T_Q_BLUR="Ativar blur? [S/n]"
    T_CFG_KEPT="Config existente mantida:"
    T_BUILD="📦 Compilando o backend em Rust..."
    T_INSTALLING="📁 Instalando em"
    T_SERVICE="Criando serviço systemd..."
    T_RUNNING="✓ Wayck rodando em background."
    T_FAILED="O serviço não iniciou."
    T_SEE_LOGS="Veja:"
    T_OPEN="Abrir o launcher:"
    T_BIND="Atalho no hyprland.lua:"
    T_CMDS="Comandos úteis:"
    T_C_STATUS="status"
    T_C_RESTART="reiniciar (após editar QML ou config)"
    T_C_STOP="parar"
    T_C_LOGS="logs ao vivo"
    T_GOOD="Boa sorte!"
else
    T_NO_PACMAN="This installer only supports Arch/CachyOS (pacman). See the manual installation in the README."
    T_Q_PKGS="Install the required packages with pacman? [Y/n]"
    T_PKGS_OK="Packages installed"
    T_ABORT="Aborting."
    T_SRC_UPDATE="📥 Updating source code..."
    T_SRC_DOWNLOAD="📥 Downloading source code..."
    T_BLUR_INFO="Blur: blurs the launcher background. Looks better, but uses more GPU."
    T_BLUR_WARN="Warning: this turns on Hyprland's global blur (translucent windows get blurred too)."
    T_Q_BLUR="Enable blur? [Y/n]"
    T_CFG_KEPT="Existing config kept:"
    T_BUILD="📦 Building the Rust backend..."
    T_INSTALLING="📁 Installing to"
    T_SERVICE="Creating systemd service..."
    T_RUNNING="✓ Wayck is running in the background."
    T_FAILED="The service did not start."
    T_SEE_LOGS="See:"
    T_OPEN="Open the launcher:"
    T_BIND="Keybind for hyprland.lua:"
    T_CMDS="Useful commands:"
    T_C_STATUS="status"
    T_C_RESTART="restart (after editing QML or config)"
    T_C_STOP="stop"
    T_C_LOGS="live logs"
    T_GOOD="Good luck!"
fi

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
    echo "${RED}${T_NO_PACMAN}${RESET}"
    exit 1
fi

# ---------- 1. Pacotes / Packages ----------
if ask "${YE}${T_Q_PKGS}${RESET} " s; then
    PKGS=(quickshell qt6-declarative qt6-wayland git base-devel wl-clipboard kitty papirus-icon-theme)
    command -v cargo >/dev/null || PKGS+=(rust)    # evita conflito com rustup / avoids rustup conflict
    sudo pacman -S --needed "${PKGS[@]}"
    echo "${GREEN}${T_PKGS_OK}${RESET}"
else
    echo "${RED}${T_ABORT}${RESET}"
    exit 1
fi

# ---------- 2. Código-fonte / Source ----------
if [[ ! -f Cargo.toml || ! -d qml ]]; then
    if [[ -d "$SRC_DIR/.git" ]]; then
        echo "$T_SRC_UPDATE"
        git -C "$SRC_DIR" pull --ff-only
    else
        echo "$T_SRC_DOWNLOAD"
        git clone --depth 1 "$REPO_URL" "$SRC_DIR"
    fi
    cd "$SRC_DIR"
fi

# ---------- 3. Blur (só na primeira instalação / first install only) ----------
if [[ ! -f "$CFG" ]]; then
    echo
    echo "${MAGENTA}${T_BLUR_INFO}${RESET}"
    echo "${YE}${T_BLUR_WARN}${RESET}"
    if ask "${MAGENTA}${T_Q_BLUR}${RESET} " s; then
        BLUR=true
    else
        BLUR=false
    fi
    mkdir -p "$CFG_DIR"
    printf '{ "blur": %s }\n' "$BLUR" > "$CFG"
else
    echo "${BLUE}${T_CFG_KEPT} $CFG${RESET}"
fi

# ---------- 4. Compilar e instalar / Build and install ----------
echo "$T_BUILD"
cargo build --release

echo "${GREEN}${T_INSTALLING} $DEST${RESET}"
mkdir -p "$DEST"
rm -f "$DEST"/*.qml
cp -r qml/. "$DEST/"
install -m755 target/release/wayck-backend "$DEST/wayck-backend"

# ---------- 5. Serviço systemd / systemd service ----------
echo "${GREEN}${T_SERVICE}${RESET}"
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
    echo "${GREEN}${T_RUNNING}${RESET}"
else
    echo "${RED}${T_FAILED}${RESET} ${T_SEE_LOGS} journalctl --user -u wayck -n 30"
fi

# ---------- 6. Final ----------
cat <<EOF

${BLUE}${T_OPEN}${RESET}
  quickshell -c wayck ipc call launcher toggle

${BLUE}${T_BIND}${RESET}
  hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd("quickshell -c wayck ipc call launcher toggle"))

${BLUE}${T_CMDS}${RESET}
  systemctl --user status wayck     # ${T_C_STATUS}
  systemctl --user restart wayck    # ${T_C_RESTART}
  systemctl --user stop wayck       # ${T_C_STOP}
  journalctl --user -u wayck -f     # ${T_C_LOGS}

${GREEN}${T_GOOD}${RESET}
EOF