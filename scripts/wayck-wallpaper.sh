#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_PATH="$(readlink -f -- "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd -- "$(dirname -- "$SCRIPT_PATH")" && pwd -P)"

DIR="${WAYCK_WALLPAPERS:-$HOME/Pictures/Wallpapers}"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

STATE_FILE="$STATE_HOME/wayck/wallpaper"
MATUGEN_DIR="$CONFIG_HOME/wayck/matugen"
MATUGEN_CONFIG="$MATUGEN_DIR/wayck.toml"
MATUGEN_TEMPLATE="$MATUGEN_DIR/templates/wayck.json"
COLORS_OUT="$STATE_HOME/quickshell/user/generated/colors.json"

THEME_MODE="${WAYCK_THEME_MODE:-dark}"
SCHEME_TYPE="${WAYCK_THEME_SCHEME:-scheme-tonal-spot}"

warn() {
    printf 'wayck-wallpaper: %s\n' "$*" >&2
}

list_wallpapers() {
    [[ -d "$DIR" ]] || return 0

    find -L "$DIR" -maxdepth 2 -type f \
        \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) |
        sort
}

current_wallpaper() {
    [[ -s "$STATE_FILE" ]] || return 1
    head -n1 "$STATE_FILE"
}

active_wallpaper() {
    command -v hyprctl >/dev/null 2>&1 || return 1

    hyprctl hyprpaper listactive 2>/dev/null |
        sed -n 's/^.*wallpaper: //p' |
        head -n1
}

ensure_matugen_config() {
    local source_template=""

    if [[ -f "$SCRIPT_DIR/assets/matugen/colors.json.template" ]]; then
        source_template="$SCRIPT_DIR/assets/matugen/colors.json.template"
    elif [[ -f "$SCRIPT_DIR/../qml/assets/matugen/colors.json.template" ]]; then
        source_template="$SCRIPT_DIR/../qml/assets/matugen/colors.json.template"
    fi

    if [[ -z "$source_template" ]]; then
        warn "template do Matugen não encontrado"
        return 1
    fi

    mkdir -p -- "$MATUGEN_DIR/templates" "$(dirname -- "$COLORS_OUT")"

    if [[ ! -f "$MATUGEN_TEMPLATE" ]]; then
        install -m 644 "$source_template" "$MATUGEN_TEMPLATE"
    fi

    if [[ ! -f "$MATUGEN_CONFIG" ]]; then
        cat > "$MATUGEN_CONFIG" <<TOML
[config]
reload_apps = false

[templates.wayck]
input_path = "$MATUGEN_TEMPLATE"
output_path = "$COLORS_OUT"
TOML
    fi
}

wait_for_hyprpaper() {
    local i

    for ((i = 0; i < 40; i++)); do
        pgrep -x hyprpaper >/dev/null 2>&1 && return 0
        sleep 0.25
    done

    return 1
}

generate_colors() {
    local img="$1"

    command -v matugen >/dev/null 2>&1 || {
        warn "matugen não encontrado; wallpaper aplicado sem atualizar as cores"
        return 0
    }

    ensure_matugen_config || return 0

    if ! matugen image "$img" \
        -c "$MATUGEN_CONFIG" \
        -m "$THEME_MODE" \
        -t "$SCHEME_TYPE" \
        --source-color-index 0 >/dev/null; then
        warn "falha ao gerar a paleta com Matugen"
        return 0
    fi

    if [[ ! -s "$COLORS_OUT" ]]; then
        warn "Matugen terminou sem gerar $COLORS_OUT"
    fi
}

set_wallpaper() {
    local img out

    img="$(realpath -- "${1:-}" 2>/dev/null)" || img=""

    if [[ -z "$img" || ! -f "$img" ]]; then
        warn "imagem não encontrada: ${1:-}"
        return 1
    fi

    if command -v hyprctl >/dev/null 2>&1; then
        if ! out="$(hyprctl hyprpaper wallpaper ",$img,cover" 2>&1)"; then
            warn "hyprpaper: $out"
            return 1
        fi

        [[ "$out" == ok* || -z "$out" ]] || warn "hyprpaper: $out"
    else
        warn "hyprctl não encontrado; não foi possível alterar o wallpaper"
        return 1
    fi

    mkdir -p -- "$(dirname -- "$STATE_FILE")"
    printf '%s\n' "$img" > "$STATE_FILE.tmp.$$"
    mv -f -- "$STATE_FILE.tmp.$$" "$STATE_FILE"

    generate_colors "$img"
}

select_relative_wallpaper() {
    local direction="$1"
    local current index=-1 next
    local -a files=()

    mapfile -t files < <(list_wallpapers)

    (("${#files[@]}" > 0)) || {
        warn "nenhum wallpaper encontrado em $DIR"
        return 1
    }

    current="$(current_wallpaper || true)"

    local i
    for i in "${!files[@]}"; do
        if [[ "${files[$i]}" == "$current" ]]; then
            index="$i"
            break
        fi
    done

    (( index >= 0 )) || index=0

    if [[ "$direction" == "next" ]]; then
        next=$(((index + 1) % ${#files[@]}))
    else
        next=$(((index - 1 + ${#files[@]}) % ${#files[@]}))
    fi

    set_wallpaper "${files[$next]}"
}

case "${1:-}" in
    list)
        list_wallpapers
        ;;
    current)
        current_wallpaper
        ;;
    set)
        set_wallpaper "${2:-}"
        ;;
    random)
        pick="$(list_wallpapers | shuf -n1)"
        [[ -n "$pick" ]] || {
            warn "nenhum wallpaper encontrado em $DIR"
            exit 1
        }
        set_wallpaper "$pick"
        ;;
    next|prev|previous)
        select_relative_wallpaper "$([[ "$1" == "next" ]] && echo next || echo prev)"
        ;;
    apply)
        wait_for_hyprpaper || warn "hyprpaper não iniciou dentro do tempo esperado"

        pick="$(current_wallpaper || true)"
        [[ -f "$pick" ]] || pick="$(active_wallpaper || true)"
        [[ -f "$pick" ]] || pick="$(list_wallpapers | head -n1)"

        [[ -n "$pick" ]] || exit 0
        set_wallpaper "$pick"
        ;;
    *)
        warn "uso: wayck-wallpaper list|current|set <imagem>|random|next|prev|apply"
        exit 1
        ;;
esac
