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
    kitty papirus-icon-theme wl-clipboard cliphist micro jq hyprpaper
)

readonly PERSONAL_REPO_PKGS=(
    micro zsh steam heroic-games-launcher lutris
)

readonly PERSONAL_AUR_PKGS=(
    vesktop-bin vscodium-bin brave-bin fastzap-bin
)

readonly PERSONAL_FLATPAK_PKGS=(
    com.dec05eba.gpu_screen_recorder
)

LANGUAGE="en"
LANG_EXPLICIT=0
AUR_HELPER=""
ROOT=""
TERMINAL_STATE=""

OPTIONS=(required blur apps hypr update build)
SELECTED=(1 1 0 0 0 1)
CURSOR=0

readonly SUPPORTED_LANGS=(
    ar az bg de en es fa fr hi hy id it ja ko nl pl pt ru tr ua vi zh zh_tw
)

# código | sistema não suportado | falha ao preparar (dependências/repositório)
readonly EARLY_MESSAGES='en|This installer only supports Arch Linux and pacman-based distributions.|Could not prepare the installation (dependencies or repository).
pt|Este instalador suporta apenas Arch Linux e derivados com pacman.|Não foi possível preparar a instalação (dependências ou repositório).
es|Este instalador solo es compatible con Arch Linux y derivados que usen pacman.|No se pudo preparar la instalación (dependencias o repositorio).
fr|Cet installateur ne prend en charge qu'"'"'Arch Linux et les distributions basées sur pacman.|Impossible de préparer l'"'"'installation (dépendances ou dépôt).
de|Dieser Installer unterstützt nur Arch Linux und pacman-basierte Distributionen.|Die Installation konnte nicht vorbereitet werden (Abhängigkeiten oder Repository).
it|Questo installer supporta solo Arch Linux e le distribuzioni basate su pacman.|Impossibile preparare l'"'"'installazione (dipendenze o repository).
nl|Dit installatieprogramma ondersteunt alleen Arch Linux en distributies op basis van pacman.|De installatie kon niet worden voorbereid (afhankelijkheden of repository).
pl|Ten instalator obsługuje tylko Arch Linux i dystrybucje oparte na pacmanie.|Nie udało się przygotować instalacji (zależności lub repozytorium).
ru|Этот установщик поддерживает только Arch Linux и дистрибутивы на основе pacman.|Не удалось подготовить установку (зависимости или репозиторий).
ua|Цей інсталятор підтримує лише Arch Linux і дистрибутиви на основі pacman.|Не вдалося підготувати встановлення (залежності або репозиторій).
bg|Този инсталатор поддържа само Arch Linux и дистрибуции, базирани на pacman.|Инсталацията не можа да бъде подготвена (зависимости или хранилище).
tr|Bu yükleyici yalnızca Arch Linux ve pacman tabanlı dağıtımları destekler.|Kurulum hazırlanamadı (bağımlılıklar veya depo).
az|Bu quraşdırıcı yalnız Arch Linux və pacman əsaslı distributivləri dəstəkləyir.|Quraşdırmanı hazırlamaq mümkün olmadı (asılılıqlar və ya anbar).
id|Penginstal ini hanya mendukung Arch Linux dan distribusi berbasis pacman.|Tidak dapat menyiapkan instalasi (dependensi atau repositori).
vi|Trình cài đặt này chỉ hỗ trợ Arch Linux và các bản phân phối dùng pacman.|Không thể chuẩn bị cài đặt (phụ thuộc hoặc kho lưu trữ).
ja|このインストーラーは Arch Linux と pacman ベースのディストリビューションのみに対応しています。|インストールの準備に失敗しました（依存関係またはリポジトリ）。
ko|이 설치 관리자는 Arch Linux 및 pacman 기반 배포판만 지원합니다.|설치를 준비하지 못했습니다(종속성 또는 저장소).
zh|此安装程序仅支持 Arch Linux 及基于 pacman 的发行版。|无法准备安装（依赖项或仓库）。
zh_tw|此安裝程式僅支援 Arch Linux 及以 pacman 為基礎的發行版。|無法準備安裝（相依套件或儲存庫）。
ar|يدعم هذا المثبّت نظام Arch Linux والتوزيعات المعتمدة على pacman فقط.|تعذّر تجهيز التثبيت (التبعيات أو المستودع).
fa|این نصب‌کننده فقط از Arch Linux و توزیع‌های مبتنی بر pacman پشتیبانی می‌کند.|آماده‌سازی نصب ممکن نبود (وابستگی‌ها یا مخزن).
hi|यह इंस्टॉलर केवल Arch Linux और pacman आधारित डिस्ट्रिब्यूशन को सपोर्ट करता है।|इंस्टॉलेशन तैयार नहीं किया जा सका (डिपेंडेंसी या रिपॉज़िटरी)।
hy|Այս տեղադրիչը աջակցում է միայն Arch Linux-ին և pacman-ի վրա հիմնված բաշխումներին։|Չհաջողվեց պատրաստել տեղադրումը (կախվածություններ կամ պահոց)։'

declare -A MSG=()
declare -a YES_WORDS=()

# pt_BR.UTF-8 -> pt | uk_UA -> ua | zh_TW -> zh_tw | desconhecido -> en
normalize_lang() {
    local raw="${1,,}"

    raw="${raw%%.*}"
    raw="${raw%%@*}"
    raw="${raw//-/_}"

    local lang="${raw%%_*}"

    [[ "$lang" == uk ]] && lang="ua"

    if [[ "$lang" == zh && "$raw" =~ ^zh_(tw|hk|mo) ]]; then
        lang="zh_tw"
    fi

    local supported
    for supported in "${SUPPORTED_LANGS[@]}"; do
        if [[ "$supported" == "$lang" ]]; then
            printf '%s' "$lang"
            return 0
        fi
    done

    printf 'en'
}

pick_lang() {
    local code="${WAYCK_LANG:-}"

    [[ -n "$code" ]] && LANG_EXPLICIT=1

    while (($#)); do
        case "$1" in
            --lang)
                code="${2:-en}"
                LANG_EXPLICIT=1
                shift
                ;;
            --lang=*)
                code="${1#*=}"
                LANG_EXPLICIT=1
                ;;
        esac
        shift
    done

    LANGUAGE="$(normalize_lang "${code:-${LC_ALL:-${LC_MESSAGES:-${LANG:-en}}}}")"
}

# Mensagens de antes do clone (ainda não existe JSON pra ler).
early_msg() {
    local key="$1" code no_pacman prepare_failed

    while IFS='|' read -r code no_pacman prepare_failed; do
        [[ "$code" == "$LANGUAGE" ]] || continue

        case "$key" in
            no_pacman) printf '%s' "$no_pacman" ;;
            *) printf '%s' "$prepare_failed" ;;
        esac

        return 0
    done <<< "$EARLY_MESSAGES"
}

# Carrega as chaves "installer.*" do inglês e depois do idioma escolhido por cima
# (o que faltar num idioma cai pro inglês, igual ao I18n.qml).
load_messages() {
    local dir="$ROOT/qml/assets/languages" file key value

    [[ -f "$dir/en.json" ]] || die "$(early_msg prepare_failed)"

    for file in "$dir/en.json" "$dir/$LANGUAGE.json"; do
        [[ -f "$file" ]] || continue

        while IFS=$'\t' read -r key value; do
            [[ -n "$key" ]] && MSG["$key"]="$value"
        done < <(jq -r '.installer | paths(scalars) as $p | "\($p | map(tostring) | join("."))\t\(getpath($p))"' "$file")
    done

    read -r -a YES_WORDS <<< "${MSG[yes_words]:-y yes}"
}

# msg chave [nome valor]...   ->  msg cfg_kept path "$config"
msg() {
    local text="${MSG[$1]:-$1}"
    shift

    while (($# >= 2)); do
        text="${text//\{$1\}/"$2"}"
        shift 2
    done

    printf '%s' "$text"
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
    local reply="" word

    printf '%s ' "$prompt"

    [[ -r /dev/tty ]] && IFS= read -r reply </dev/tty || true
    reply="${reply,,}"
    reply="${reply//[[:space:]]/}"

    if [[ -z "$reply" ]]; then
        [[ "$default_yes" == true ]]
        return
    fi

    for word in "${YES_WORDS[@]}" y yes; do
        [[ "$reply" == "${word,,}" ]] && return 0
    done

    return 1
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
    have pacman || die "$(early_msg no_pacman)"

    local -a missing=()

    have git || missing+=(git)
    have cargo || missing+=(rust)
    have cc || missing+=(base-devel)
    have jq || missing+=(jq)

    if ((${#missing[@]})); then
        must "$(early_msg prepare_failed)" \
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
            must "$(early_msg prepare_failed)" \
                git -C "$SRC_DIR" pull --ff-only
        else
            must "$(early_msg prepare_failed)" \
                git clone --depth 1 "$REPO_URL" "$SRC_DIR"
        fi

        ROOT="$SRC_DIR"
    fi

    [[ -f "$ROOT/Cargo.toml" && -d "$ROOT/qml" ]] ||
        die "$(early_msg prepare_failed)"

    load_messages
}

# ============================================================
# INTERACTIVE MENU
# ============================================================

menu_label() {
    msg "menu.$1"
}

interactive_menu() {
    [[ -t 0 ]] || die "$(msg tty_required)"

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

    must "$(msg pkgs_failed)" \
        sudo pacman -S --needed "${REQUIRED_PKGS[@]}"

    printf '%b%s%b\n' "$GREEN" "$(msg pkgs_ok)" "$RESET"
}

# ============================================================
# BLUR CONFIGURATION
# ============================================================

# config_set <chave> <valor-json>   (mexe só nessa chave, o resto do config.json fica intacto)
config_set() {
    local key="$1" value="$2"
    local config="$CFG_DIR/config.json" temp

    mkdir -p -- "$CFG_DIR"

    if [[ -f "$config" ]]; then
        have jq || die "$(msg missing_tool name jq)"
        jq -e 'type == "object"' "$config" >/dev/null ||
            die "$(msg invalid_config)"

        temp="$(mktemp "$CFG_DIR/.config.XXXXXX")"

        if ! jq --arg key "$key" --argjson value "$value" '.[$key] = $value' "$config" > "$temp"; then
            rm -f -- "$temp"
            die "$(msg invalid_config)"
        fi

        chmod --reference="$config" "$temp" 2>/dev/null || true
        mv -- "$temp" "$config"
    else
        jq -n --arg key "$key" --argjson value "$value" '{($key): $value}' > "$config" ||
            die "$(msg invalid_config)"
    fi

    printf '%b%s%b\n' "$GREEN" "$(msg cfg_kept path "$config")" "$RESET"
}

setup_blur() {
    printf '\n%b%s%b\n' "$MAGENTA" "$(msg blur_info)" "$RESET"
    printf '%b%s%b\n' "$YELLOW" "$(msg blur_warn)" "$RESET"

    local blur=false

    ask "$(msg q_blur) $(msg hint_yes)" true && blur=true

    config_set blur "$blur"
}

persist_language() {
    ((LANG_EXPLICIT)) || return 0

    config_set language "\"$LANGUAGE\""
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

    printf '%b%s%b\n' \
        "$BLUE" "$(msg aur_installing name "$AUR_HELPER")" "$RESET"

    have git || die "$(msg missing_tool name git)"
    have makepkg || die "$(msg missing_tool name makepkg)"

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

    printf '%b%s%b\n' "$GREEN" "$(msg aur_installed name "$AUR_HELPER")" "$RESET"
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
    must "$(msg personal_failed)" \
        flatpak install flathub "${PERSONAL_FLATPAK_PKGS[@]}"

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
update_dot() {
    printf '\n%b%s%b\n' "$BLUE" "$(msg update.pulling)" "$RESET"

    must "$(msg update.pull_failed)" \
        git -C "$ROOT" pull --ff-only

    printf '%b%s%b\n' "$BLUE" "$(msg update.compiling)" "$RESET"

    must "$(msg update.compile_failed)" \
        cargo build --release --bin wayck-backend \
        --manifest-path "$ROOT/Cargo.toml"

    local parent
    parent="$(dirname "$DEST")"

    mkdir -p -- "$parent"

    UPDATE_STAGE="$(mktemp -d "$parent/.wayck.XXXXXX")"

    if ! copy_dir "$ROOT/qml" "$UPDATE_STAGE"; then
        rm -rf -- "$UPDATE_STAGE"
        UPDATE_STAGE=""
        die "$(msg update.copy_failed)"
    fi

    install -m 755 \
        "$ROOT/target/release/wayck-backend" \
        "$UPDATE_STAGE/wayck-backend"

    install -m 755 \
        "$ROOT/scripts/wayck-wallpaper.sh" \
        "$UPDATE_STAGE/wayck-wallpaper"

    install -m 755 \
        "$ROOT/install.sh" \
        "$UPDATE_STAGE/install.sh"

    printf '%b%s%b\n' "$YELLOW" "$(msg update.stopping)" "$RESET"

    quickshell -c wayck kill 2>/dev/null || true

    if [[ -e "$DEST" || -L "$DEST" ]]; then
        UPDATE_BACKUP="${DEST}.backup-$(date +%Y%m%d-%H%M%S)"

        must "$(msg update.backup_failed)" \
            mv -- "$DEST" "$UPDATE_BACKUP"
    fi

    printf '%b%s%b\n' "$GREEN" "$(msg update.installing)" "$RESET"

    if ! mv -- "$UPDATE_STAGE" "$DEST"; then
        [[ -n "$UPDATE_BACKUP" ]] &&
            mv -- "$UPDATE_BACKUP" "$DEST" || true

        rm -rf -- "$UPDATE_STAGE"
        UPDATE_STAGE=""

        die "$(msg update.install_failed)"
    fi

    UPDATE_STAGE=""

    mkdir -p -- "$HOME/.local/bin"

    ln -sf -- "$DEST/wayck-wallpaper" \
        "$HOME/.local/bin/wayck-wallpaper"

    printf '%b%s%b\n' "$GREEN" "$(msg update.done)" "$RESET"

    [[ -n "$UPDATE_BACKUP" ]] &&
        printf '%s: %s\n' "$(msg update.backup)" "$UPDATE_BACKUP"
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
        die "$(msg fail_copy)"
    fi

    install -m 755 "$ROOT/target/release/wayck-backend" "$stage/wayck-backend"
    install -m 755 "$ROOT/scripts/wayck-wallpaper.sh" "$stage/wayck-wallpaper"
    install -m 755 "$ROOT/install.sh" "$stage/install.sh"

    printf '%b%s%b\n' "$GREEN" "$(msg installing path "$DEST")" "$RESET"

    if [[ -e "$DEST" || -L "$DEST" ]]; then
        backup="${DEST}.backup-$(date +%Y%m%d-%H%M%S)"

        mv -- "$DEST" "$backup" || {
            rm -rf -- "$stage"
            die "$(msg fail_backup)"
        }
    fi

    if ! mv -- "$stage" "$DEST"; then
        [[ -n "$backup" ]] && mv -- "$backup" "$DEST" || true
        rm -rf -- "$stage"
        die "$(msg fail_install)"
    fi

    # Atalho "wayck-wallpaper" no PATH (o menu e o exec.lua usam o do DEST direto).
    mkdir -p -- "$HOME/.local/bin"
    ln -sf -- "$DEST/wayck-wallpaper" "$HOME/.local/bin/wayck-wallpaper"

    install_matugen
}

# matugen gera as cores a partir do wallpaper. É opcional: sem ele o Wayck usa
# as cores padrão do Theme.qml, então se só o pacote falhar a instalação continua.
install_matugen() {
    have matugen && return 0

    install_aur_helper

    "$AUR_HELPER" -S --needed matugen-bin ||
        printf '%b%s%b\n' "$YELLOW" "$(msg aur_install_failed)" "$RESET"
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
            die "$(msg fail_backup)"

        printf '%b%s%b\n' "$GREEN" "$(msg hypr_backup path "$backup")" "$RESET"
    fi

    mkdir -p -- "$CONFIG_HOME"

    cp -a -- "$source" "$CONFIG_HOME/" ||
        die "$(msg fail_install)"

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

    printf '\n%s\n' "$(msg useful_commands)"
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
    # Non-interactive update entrypoint used by the bar's hold-to-confirm UI.
    # The detached process survives the Quickshell restart performed by update_dot.
    if [[ "${1:-}" == "--update-only" ]]; then
        pick_lang
        bootstrap
        update_dot
        mkdir -p -- "${XDG_STATE_HOME:-$HOME/.local/state}/wayck"
        nohup quickshell -c wayck \
            > "${XDG_STATE_HOME:-$HOME/.local/state}/wayck/update-shell.log" 2>&1 &
        return 0
    fi

    pick_lang "$@"
    bootstrap

    interactive_menu || die "$(msg abort)"

    (( SELECTED[0] )) && install_packages
    (( SELECTED[2] )) && install_personal_apps
    (( SELECTED[1] )) && setup_blur
    (( SELECTED[3] )) && install_hypr
    (( SELECTED[4] )) && update_dot
    (( SELECTED[5] )) && build_and_install

    persist_language

    print_final
}

if [[ "${BASH_SOURCE[0]:-$0}" == "$0" ]]; then
    main "$@"
fi