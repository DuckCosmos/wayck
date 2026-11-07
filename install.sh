#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================
# WAYCK INSTALLER
# ============================================================

readonly REPO_URL="https://github.com/DuckCosmos/wayck.git"
readonly SRC_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/wayck-src"
readonly HOME_DIR="${HOME:?HOME is not defined}"
readonly CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME_DIR/.config}"
readonly CFG_DIR="$CONFIG_HOME/wayck"
readonly DEST="$CONFIG_HOME/quickshell/wayck"

readonly RED='\033[31m'
readonly GREEN='\033[32m'
readonly YELLOW='\033[33m'
readonly BLUE='\033[34m'
readonly MAGENTA='\033[35m'
readonly RESET='\033[0m'

readonly REQUIRED_PKGS=(
    quickshell qt6-declarative qt6-wayland git base-devel
    kitty papirus-icon-theme wl-clipboard cliphist micro jq
)

readonly PERSONAL_REPO_PKGS=(
    obs-studio micro zsh steam heroic-games-launcher lutris
)

readonly PERSONAL_AUR_PKGS=(
    vesktop-bin vscodium-bin brave-bin
)

LANGUAGE="en"
AUR_HELPER=""
ROOT=""
TERMINAL_STATE=""

OPTIONS=(required blur apps hypr build)
SELECTED=(1 1 0 0 1)
CURSOR=0

# ============================================================
# TRANSLATIONS
# ============================================================

pick_lang() {
    local code="${WAYCK_LANG:-${LANG:-en}}"

    while (($#)); do
        case "$1" in
            --lang)
                code="${2:-en}"
                shift
                ;;
            --lang=*)
                code="${1#*=}"
                ;;
        esac
        shift
    done

    [[ "${code,,}" == pt* ]] && LANGUAGE="pt" || LANGUAGE="en"
}

msg() {
    local key="$1"

    if [[ "$LANGUAGE" == pt ]]; then
        case "$key" in
            title) printf 'INSTALADOR WAYCK' ;;
            help) printf 'Use as setas para navegar, ESPAÇO para selecionar e ENTER para continuar. ESC para sair.' ;;
            required) printf 'Instalar pacotes necessários' ;;
            blur) printf 'Configurar blur' ;;
            apps) printf 'Instalar meus aplicativos' ;;
            hypr) printf 'Instalar configurações do Hyprland' ;;
            build) printf 'Compilar e instalar Wayck' ;;
            confirm) printf 'ENTER: continuar | ESPAÇO: selecionar | ESC: sair' ;;
            no_pacman) printf 'Este instalador suporta apenas Arch Linux e derivados com pacman.' ;;
            abort) printf 'Instalação cancelada.' ;;
            pkgs_installing) printf 'Instalando pacotes necessários...' ;;
            pkgs_ok) printf 'Pacotes necessários instalados.' ;;
            blur_info) printf 'Blur: aplica desfoque ao fundo do launcher.' ;;
            blur_warn) printf 'Aviso: o blur também pode afetar outras janelas translúcidas do Hyprland.' ;;
            q_blur) printf 'Ativar blur? [S/n]' ;;
            cfg_kept) printf 'Configuração atualizada:' ;;
            invalid_config) printf 'O config.json existente não contém um objeto JSON válido.' ;;
            build_msg) printf 'Compilando o backend em Rust...' ;;
            installing) printf 'Instalando em' ;;
            build_failed) printf 'Falha ao compilar o backend.' ;;
            hypr_q) printf 'Instalar o preset do Wayck em ~/.config/hypr? Um backup será criado. [s/N]' ;;
            hypr_backup) printf 'BACKUP SALVO EM' ;;
            hypr_done) printf 'Configuração do Hyprland instalada.' ;;
            hypr_missing) printf 'Hyprland não encontrado ou pasta hypr/ ausente. Pulando configuração.' ;;
            aur_installing) printf 'Instalando' ;;
            aur_already) printf 'já está instalado. Pulando.' ;;
            aur_clone_failed) printf 'Falha ao baixar o repositório AUR.' ;;
            aur_build_failed) printf 'Falha ao compilar ou instalar um pacote AUR.' ;;
            aur_install_failed) printf 'O helper AUR não foi instalado corretamente.' ;;
            aur_installed) printf 'instalado com sucesso.' ;;
            personal_installing) printf 'Instalando aplicativos pessoais...' ;;
            personal_failed) printf 'Falha ao instalar os aplicativos pessoais.' ;;
            zsh_changed) printf 'Zsh configurado como shell padrão. A alteração vale no próximo login.' ;;
            zsh_failed) printf 'Não foi possível alterar o shell padrão para Zsh.' ;;
            steam_note) printf 'O Steam pode exigir que o repositório multilib esteja habilitado no pacman.conf.' ;;
            final_title) printf 'INSTALAÇÃO CONCLUÍDA' ;;
            final_exec) printf 'O Wayck será iniciado pelo seu exec.lua após a reinicialização.' ;;
            reboot) printf 'REINICIE O COMPUTADOR. ESTA ETAPA É OBRIGATÓRIA.' ;;
            good) printf 'Obrigado por instalar o Wayck.' ;;
            *) printf '%s' "$key" ;;
        esac
    else
        case "$key" in
            title) printf 'WAYCK INSTALLER' ;;
            help) printf 'Use arrow keys to navigate, SPACE to select and ENTER to continue. ESC to exit.' ;;
            required) printf 'Install required packages' ;;
            blur) printf 'Configure blur' ;;
            apps) printf 'Install my applications' ;;
            hypr) printf 'Install Hyprland configuration' ;;
            build) printf 'Build and install Wayck' ;;
            confirm) printf 'ENTER: continue | SPACE: select | ESC: exit' ;;
            no_pacman) printf 'This installer only supports Arch Linux and pacman-based distributions.' ;;
            abort) printf 'Installation cancelled.' ;;
            pkgs_installing) printf 'Installing required packages...' ;;
            pkgs_ok) printf 'Required packages installed.' ;;
            blur_info) printf 'Blur: applies background blur to the launcher.' ;;
            blur_warn) printf 'Warning: blur may also affect other translucent Hyprland windows.' ;;
            q_blur) printf 'Enable blur? [Y/n]' ;;
            cfg_kept) printf 'Configuration updated:' ;;
            invalid_config) printf 'The existing config.json does not contain a valid JSON object.' ;;
            build_msg) printf 'Building the Rust backend...' ;;
            installing) printf 'Installing to' ;;
            build_failed) printf 'Failed to build the backend.' ;;
            hypr_q) printf 'Install the Wayck preset into ~/.config/hypr? A backup will be created. [y/N]' ;;
            hypr_backup) printf 'BACKUP SAVED TO' ;;
            hypr_done) printf 'Hyprland configuration installed.' ;;
            hypr_missing) printf 'Hyprland not found or hypr/ directory missing. Skipping configuration.' ;;
            aur_installing) printf 'Installing' ;;
            aur_already) printf 'is already installed. Skipping.' ;;
            aur_clone_failed) printf 'Failed to clone the AUR repository.' ;;
            aur_build_failed) printf 'Failed to build or install an AUR package.' ;;
            aur_install_failed) printf 'The AUR helper was not installed correctly.' ;;
            aur_installed) printf 'installed successfully.' ;;
            personal_installing) printf 'Installing personal applications...' ;;
            personal_failed) printf 'Failed to install personal applications.' ;;
            zsh_changed) printf 'Zsh set as the default shell. The change takes effect at the next login.' ;;
            zsh_failed) printf 'Could not change the default shell to Zsh.' ;;
            steam_note) printf 'Steam may require the multilib repository to be enabled in pacman.conf.' ;;
            final_title) printf 'INSTALLATION COMPLETED' ;;
            final_exec) printf 'Wayck will be started by your exec.lua after reboot.' ;;
            reboot) printf 'REBOOT YOUR COMPUTER. THIS STEP IS REQUIRED.' ;;
            good) printf 'Thank you for installing Wayck.' ;;
            *) printf '%s' "$key" ;;
        esac
    fi
}

# ============================================================
# TERMINAL AND UTILITIES
# ============================================================

have() {
    command -v "$1" >/dev/null 2>&1
}

die() {
    printf '\n%b%s%b\n' "$RED" "$1" "$RESET" >&2
    exit 1
}

must() {
    local message="$1"
    shift
    "$@" || die "$message"
}

restore_terminal() {
    if [[ -n "$TERMINAL_STATE" && -t 0 ]]; then
        stty "$TERMINAL_STATE" 2>/dev/null || true
        tput cnorm 2>/dev/null || true
        TERMINAL_STATE=""
    fi
}

cleanup() {
    restore_terminal
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

ask() {
    local prompt="$1"
    local default_yes="${2:-false}"
    local reply=""

    printf '%s ' "$prompt"

    [[ -r /dev/tty ]] && IFS= read -r reply </dev/tty || true
    reply="${reply,,}"

    if [[ -z "$reply" ]]; then
        [[ "$default_yes" == true ]]
        return
    fi

    [[ "$reply" =~ ^(s|y|sim|yes)$ ]]
}

backup_path() {
    local target="$1"
    [[ -e "$target" || -L "$target" ]] || return 0

    local backup
    backup="${target}.backup-$(date +%Y%m%d-%H%M%S)"
    mv -- "$target" "$backup" || return 1
    printf '%s\n' "$backup"
}

copy_dir() {
    local source="$1"
    local destination="$2"

    [[ -d "$source" ]] || return 1
    mkdir -p -- "$destination"
    cp -a -- "$source/." "$destination/"
}

# ============================================================
# REPOSITORY BOOTSTRAP
# ============================================================

bootstrap() {
    have pacman || die "$(msg no_pacman)"

    local -a missing=()

    have git || missing+=(git)
    have cargo || missing+=(rust)
    have cc || missing+=(base-devel)

    if ((${#missing[@]})); then
        must "Failed to install dependencies." \
            sudo pacman -S --needed "${missing[@]}"
    fi

    if [[ -f "${BASH_SOURCE[0]}" ]]; then
        local script_dir
        script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

        if [[ -f "$script_dir/Cargo.toml" && -d "$script_dir/qml" ]]; then
            ROOT="$script_dir"
        fi
    fi

    if [[ -z "$ROOT" ]]; then
        mkdir -p -- "$(dirname "$SRC_DIR")"

        if [[ -d "$SRC_DIR/.git" ]]; then
            must "Failed to update Wayck repository." \
                git -C "$SRC_DIR" pull --ff-only
        else
            must "Failed to clone Wayck repository." \
                git clone --depth 1 "$REPO_URL" "$SRC_DIR"
        fi

        ROOT="$SRC_DIR"
    fi

    [[ -f "$ROOT/Cargo.toml" && -d "$ROOT/qml" ]] ||
        die "Invalid Wayck repository."
}

# ============================================================
# INTERACTIVE MENU
# ============================================================

menu_label() {
    msg "$1"
}

interactive_menu() {
    [[ -t 0 ]] || die "Interactive terminal required."

    TERMINAL_STATE="$(stty -g)"
    tput civis 2>/dev/null || true
    stty -echo -icanon min 1 time 0

    local key sequence index label pointer checkbox

    while true; do
        printf '\033[H\033[2J'
        printf '%b========================================%b\n' "$BLUE" "$RESET"
        printf '%b%s%b\n\n' "$GREEN" "$(msg title)" "$RESET"
        printf '%s\n\n' "$(msg help)"

        for index in "${!OPTIONS[@]}"; do
            label="$(menu_label "${OPTIONS[$index]}")"
            pointer=" "
            checkbox=" "

            [[ "$index" == "$CURSOR" ]] && pointer=">"
            [[ "${SELECTED[$index]}" == 1 ]] && checkbox="x"

            if [[ "$index" == "$CURSOR" ]]; then
                printf '%b%s [%s] %s%b\n' "$GREEN" "$pointer" "$checkbox" "$label" "$RESET"
            else
                printf '%s [%s] %s\n' "$pointer" "$checkbox" "$label"
            fi
        done

        printf '\n%b%s%b\n' "$YELLOW" "$(msg confirm)" "$RESET"

        key=""
        IFS= read -rsn1 key || true

        case "$key" in
            $'\x1b')
                sequence=""
                IFS= read -rsn2 -t 0.1 sequence || true

                case "$sequence" in
                    "[A") (( CURSOR > 0 )) && ((CURSOR--)) || true ;;
                    "[B") (( CURSOR < ${#OPTIONS[@]} - 1 )) && ((CURSOR++)) || true ;;
                    "") restore_terminal; return 1 ;;
                esac
                ;;
            " ")
                if (( SELECTED[CURSOR] )); then
                    SELECTED[CURSOR]=0
                else
                    SELECTED[CURSOR]=1
                fi
                ;;
            "")
                restore_terminal
                printf '\n'
                return 0
                ;;
        esac
    done
}

# ============================================================
# REQUIRED PACKAGES
# ============================================================

install_packages() {
    printf '%b%s%b\n' "$BLUE" "$(msg pkgs_installing)" "$RESET"

    must "$(msg personal_failed)" \
        sudo pacman -S --needed "${REQUIRED_PKGS[@]}"

    printf '%b%s%b\n' "$GREEN" "$(msg pkgs_ok)" "$RESET"
}

# ============================================================
# BLUR CONFIGURATION
# ============================================================

setup_blur() {
    printf '\n%b%s%b\n' "$MAGENTA" "$(msg blur_info)" "$RESET"
    printf '%b%s%b\n' "$YELLOW" "$(msg blur_warn)" "$RESET"

    mkdir -p -- "$CFG_DIR"

    local config="$CFG_DIR/config.json"
    local blur=false

    ask "$(msg q_blur)" true && blur=true

    if [[ -f "$config" ]]; then
        have jq || die "jq is required to modify config.json safely."
        jq -e 'type == "object"' "$config" >/dev/null ||
            die "$(msg invalid_config)"

        local temp
        temp="$(mktemp "$CFG_DIR/.config.XXXXXX")"

        if ! jq --argjson blur "$blur" '.blur = $blur' "$config" > "$temp"; then
            rm -f -- "$temp"
            die "$(msg invalid_config)"
        fi

        chmod --reference="$config" "$temp" 2>/dev/null || true
        mv -- "$temp" "$config"
    else
        printf '{\n  "blur": %s\n}\n' "$blur" > "$config"
    fi

    printf '%b%s %s%b\n' "$GREEN" "$(msg cfg_kept)" "$config" "$RESET"
}

# ============================================================
# AUR
# ============================================================

install_aur_helper() {
    if have paru; then
        AUR_HELPER=paru
        return 0
    elif have yay; then
        AUR_HELPER=yay
        return 0
    fi

    AUR_HELPER=paru

    printf '%b%s %s...%b\n' \
        "$BLUE" "$(msg aur_installing)" "$AUR_HELPER" "$RESET"

    have git || die "Git is required."
    have makepkg || die "makepkg is required."

    local build_dir
    build_dir="$(mktemp -d "${TMPDIR:-/tmp}/wayck-aur.XXXXXX")"

    if ! git clone "https://aur.archlinux.org/${AUR_HELPER}.git" "$build_dir/$AUR_HELPER"; then
        rm -rf -- "$build_dir"
        die "$(msg aur_clone_failed)"
    fi

    if ! (
        cd "$build_dir/$AUR_HELPER"
        makepkg -si --needed --noconfirm
    ); then
        rm -rf -- "$build_dir"
        die "$(msg aur_build_failed)"
    fi

    rm -rf -- "$build_dir"
    have "$AUR_HELPER" || die "$(msg aur_install_failed)"

    printf '%b%s %s%b\n' "$GREEN" "$AUR_HELPER" "$(msg aur_installed)" "$RESET"
}

# ============================================================
# PERSONAL APPLICATIONS
# ============================================================

install_personal_apps() {
    printf '\n%b%s%b\n' "$BLUE" "$(msg personal_installing)" "$RESET"
    printf '%b%s%b\n' "$YELLOW" "$(msg steam_note)" "$RESET"

    install_aur_helper

    must "$(msg personal_failed)" \
        sudo pacman -S --needed "${PERSONAL_REPO_PKGS[@]}"

    must "$(msg personal_failed)" \
        "$AUR_HELPER" -S --needed "${PERSONAL_AUR_PKGS[@]}"

    if have zsh; then
        local zsh_path
        zsh_path="$(command -v zsh)"

        if [[ "${SHELL:-}" != "$zsh_path" ]]; then
            must "$(msg zsh_failed)" chsh -s "$zsh_path"
            printf '%b%s%b\n' "$GREEN" "$(msg zsh_changed)" "$RESET"
        fi
    fi
}

# ============================================================
# BUILD AND INSTALL
# ============================================================

build_and_install() {
    printf '\n%b%s%b\n' "$BLUE" "$(msg build_msg)" "$RESET"

    must "$(msg build_failed)" \
        cargo build --release --bin wayck-backend \
        --manifest-path "$ROOT/Cargo.toml"

    local parent stage backup=""
    parent="$(dirname "$DEST")"

    mkdir -p -- "$parent"
    stage="$(mktemp -d "$parent/.wayck.XXXXXX")"

    if ! copy_dir "$ROOT/qml" "$stage"; then
        rm -rf -- "$stage"
        die "Failed to copy QML files."
    fi

    install -m 755 "$ROOT/target/release/wayck-backend" "$stage/wayck-backend"

    printf '%b%s %s%b\n' "$GREEN" "$(msg installing)" "$DEST" "$RESET"

    if [[ -e "$DEST" || -L "$DEST" ]]; then
        backup="${DEST}.backup-$(date +%Y%m%d-%H%M%S)"

        mv -- "$DEST" "$backup" || {
            rm -rf -- "$stage"
            die "Failed to backup existing installation."
        }
    fi

    if ! mv -- "$stage" "$DEST"; then
        [[ -n "$backup" ]] && mv -- "$backup" "$DEST" || true
        rm -rf -- "$stage"
        die "Failed to install Wayck."
    fi
}

# ============================================================
# HYPRLAND
# ============================================================

install_hypr() {
    local source="$ROOT/hypr"
    local destination="$CONFIG_HOME/hypr"

    if [[ ! -d "$source" ]] || ! have Hyprland; then
        printf '%b%s%b\n' "$YELLOW" "$(msg hypr_missing)" "$RESET"
        return 0
    fi

    ask "$(msg hypr_q)" false || return 0

    if [[ -e "$destination" || -L "$destination" ]]; then
        local backup
        backup="$(backup_path "$destination")" ||
            die "Failed to backup Hyprland configuration."

        printf '%b%s: %s%b\n' "$GREEN" "$(msg hypr_backup)" "$backup" "$RESET"
    fi

    copy_dir "$source" "$CONFIG_HOME" ||
        die "Failed to install Hyprland configuration."

    printf '%b%s%b\n' "$GREEN" "$(msg hypr_done)" "$RESET"
}

# ============================================================
# FINAL MESSAGE
# ============================================================

print_final() {
    printf '\n%b========================================%b\n' "$GREEN" "$RESET"
    printf '%b%s%b\n' "$GREEN" "$(msg final_title)" "$RESET"
    printf '%b========================================%b\n' "$GREEN" "$RESET"

    printf '\n%b%s%b\n' "$BLUE" "$(msg final_exec)" "$RESET"

    printf '\nUseful commands:\n'
    printf '  quickshell -c wayck\n'
    printf '  quickshell -c wayck ipc call launcher toggle\n'
    printf '  pkill -f "quickshell -c wayck"\n'

    printf '\n%b%s%b\n' "$GREEN" "$(msg good)" "$RESET"
    printf '\n%b========================================%b\n' "$RED" "$RESET"
    printf '%b%s%b\n' "$RED" "$(msg reboot)" "$RESET"
    printf '%b========================================%b\n' "$RED" "$RESET"
}

# ============================================================
# MAIN
# ============================================================

main() {
    pick_lang "$@"
    bootstrap

    interactive_menu || die "$(msg abort)"

    (( SELECTED[0] )) && install_packages
    (( SELECTED[2] )) && install_personal_apps
    (( SELECTED[1] )) && setup_blur
    (( SELECTED[3] )) && install_hypr
    (( SELECTED[4] )) && build_and_install

    print_final
}

main "$@"