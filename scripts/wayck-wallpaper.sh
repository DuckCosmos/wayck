#!/usr/bin/env bash

set -euo pipefail

DIR="${WAYCK_WALLPAPERS:-$HOME/Pictures/Wallpapers}"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

STATE_FILE="$STATE_HOME/wayck/wallpaper"
MATUGEN_DIR="$CONFIG_HOME/wayck/matugen"
MATUGEN_CONFIG="$MATUGEN_DIR/config.toml"
MATUGEN_TEMPLATE="$MATUGEN_DIR/templates/colors.json"

COLORS_OUT="$STATE_HOME/quickshell/user/generated/colors.json"

warn() { printf 'wayck-wallpaper: %s\n' "$*" >&2; }

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

ensure_matugen_config() {
    mkdir -p -- "$MATUGEN_DIR/templates" "$(dirname -- "$COLORS_OUT")"

    if [[ ! -f "$MATUGEN_TEMPLATE" ]]; then
        cat > "$MATUGEN_TEMPLATE" <<'TEMPLATE'
{
  "primary": "{{colors.primary.default.hex}}",
  "on_primary": "{{colors.on_primary.default.hex}}",
  "surface_container_high": "{{colors.surface_container_high.default.hex}}",
  "on_surface": "{{colors.on_surface.default.hex}}",
  "outline": "{{colors.outline.default.hex}}"
}
TEMPLATE
    fi

    if [[ ! -f "$MATUGEN_CONFIG" ]]; then
        cat > "$MATUGEN_CONFIG" <<TOML
[config]

[templates.wayck]
input_path = '$MATUGEN_TEMPLATE'
output_path = '$COLORS_OUT'
TOML
    fi
}

wait_for_hyprpaper() {
    local i

    for i in $(seq 1 20); do
        pgrep -x hyprpaper >/dev/null 2>&1 && return 0
        sleep 0.25
    done

    return 1
}

set_wallpaper() {
    local img

    img="$(realpath -- "${1:-}" 2>/dev/null)" || img=""

    if [[ -z "$img" || ! -f "$img" ]]; then
        warn "imagem não encontrada: ${1:-}"
        return 1
    fi

    mkdir -p -- "$(dirname -- "$STATE_FILE")"
    printf '%s\n' "$img" > "$STATE_FILE"

    if command -v hyprctl >/dev/null 2>&1; then
        local out
        out="$(hyprctl hyprpaper wallpaper ",$img,cover" 2>&1)" || true

        [[ "$out" == ok* || -z "$out" ]] || warn "hyprpaper: $out"
    else
        warn "hyprctl não encontrado"
    fi

    if command -v matugen >/dev/null 2>&1; then
        ensure_matugen_config

        matugen --config "$MATUGEN_CONFIG" image "$img" --source-color-index 0 </dev/null >/dev/null ||
            warn "matugen falhou"
    else
        warn "matugen não encontrado; o wallpaper trocou, mas as cores não"
    fi
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
        [[ -n "$pick" ]] || { warn "nenhuma imagem em $DIR"; exit 1; }
        set_wallpaper "$pick"
        ;;
    apply)
        wait_for_hyprpaper || warn "hyprpaper não iniciou"

        pick="$(current_wallpaper || true)"
        [[ -f "$pick" ]] || pick="$(list_wallpapers | head -n1)"

        [[ -n "$pick" ]] || exit 0

        set_wallpaper "$pick"
        ;;
    *)
        warn "uso: wayck-wallpaper list|current|set <imagem>|random|apply"
        exit 1
        ;;
esac