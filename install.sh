#!/usr/bin/env bash
set -euo pipefail
RED=$'\e[31m'
GREEN=$'\e[32m'
YE=$'\e[33m'
BLUE=$'\e[34m'
MAGENTA=$'\e[35m'
RESET=$'\e[0m'

CFG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/wayck"
CFG="$CFG_DIR/config.json"

read -rp "🇧🇷 ${RED}AVISO:${RESET} ${YE}Alguns pacotes são necessários para instalaçào do Wayck, Deseja baixá-los? [s/N] ${RESET}| 🇺🇸${RED}WARNING:${RESET} ${YE}Some packages are required to install Wayck, Do you want to download them? [y/N]${BLUE}" ans
echo -n "${RESET}"
ans="${ans:-y}"
ans="${ans,,}"

case "$ans" in
    s|y|sim|yes)
        sudo pacman -S --needed quickshell qt6-declarative qt6-wayland rust cargo base-devel wl-clipboard kitty papirus-icon-theme
        echo "${GREEN}Pacotes instalados com sucesso | Successfully installed packages${RESET}"
        ;;
    *)
        echo "${RED}Abortando instalação.${RESET}"
        exit
        ;;
esac

read -rp "🇧🇷 ${MAGENTA}Deseja ativar o blur no Launcher? Fica mais atraente, porém, custa mais da sua GPU. [s/N] ${RESET}| 🇺🇸 ${MAGENTA}Do you want to enable blur in Launcher? It looks more attractive, but it costs more of your GPU. [y/N]${BLUE}" blr
echo -n "${RESET}"
blr="${blr:-y}"
blr="${blr,,}"

case "$blr" in
    s|y|sim|yes)
        BLUR=true
        ;;
    *)
        BLUR=false
        ;;
esac

mkdir -p "${CFG_DIR}"
printf '{ "blur": %s }\n' "$BLUR" > "${CFG}"

if [[ "${BLUR}" == true ]]; then
    echo "Blur: ${GREEN}(Ativo)${RESET} | Blur: ${GREEN}(Actived)${RESET}"
fi

echo "📦 Compilando backend em ${RED}Rust...${RESET}"
cargo build --release

echo "📁 ${GREEN}Instalando arquivos em ~/.config/quickshell/wayck/...${RESET}"
mkdir -p ~/.config/quickshell/wayck
cp target/release/wayck-backend ~/.config/quickshell/wayck/
cp qml/*.qml ~/.config/quickshell/wayck/

echo "${GREEN}Criando service systemd...${RESET}"

mkdir -p ~/.config/systemd/user

cat > ~/.config/systemd/user/wayck.service <<'EOF'
[Unit]
Description=Wayck Launcher (Quickshell)
After=graphical-session.target
PartOf=graphical-session.target

[Service]
Type=simple
ExecStart=/usr/bin/quickshell -p %h/.config/quickshell/wayck
Restart=on-failure
RestartSec=3

[Install]
WantedBy=graphical-session.target
EOF

echo "${GREEN}✓ Service criado.${RESET}"
echo "${YE}Ativando...${RESET}"

systemctl --user daemon-reload
systemctl --user enable --now wayck.service

echo "${GREEN}✓ Wayck rodando em background.${RESET}"
echo ""
echo "${BLUE}Comandos úteis | Utils Commands:${RESET}"
echo "  systemctl --user status wayck      # ver status"
echo "  systemctl --user restart wayck     # reiniciar (após editar QML)"
echo "  systemctl --user stop wayck        # parar"
echo "  journalctl --user -u wayck -f      # ver logs ao vivo"
echo "${BLUE}Commands Run: quickshell -c wayck ipc call launcher toggle | Shortcut: hl.bind(mainMod .. \" + SPACE\",  hl.dsp.exec_cmd(\"quickshell -c wayck ipc call launcher toggle\"))${RESET}"

echo "${GREEN}Good Luck!${RESET}"