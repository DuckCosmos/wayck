#!/usr/bin/env bash
set -Eeuo pipefail

PICTURES_DIR="$(xdg-user-dir PICTURES 2>/dev/null || printf '%s' "$HOME/Pictures")"

DIR="${WAYCK_WALLPAPERS:-$PICTURES_DIR/Wallpapers}"

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

STATE_DIR="$STATE_HOME/wayck"
STATE_FILE="$STATE_DIR/wallpaper"

MATUGEN_DIR="$CONFIG_HOME/wayck/matugen"
MATUGEN_CONFIG="$MATUGEN_DIR/wayck.toml"
MATUGEN_TEMPLATE="$MATUGEN_DIR/templates/wayck.json"

COLORS_OUT="$STATE_HOME/quickshell/user/generated/colors.json"

THEME_MODE="${WAYCK_THEME_MODE:-dark}"
SCHEME_TYPE="${WAYCK_THEME_SCHEME:-scheme-tonal-spot}"

mkdir -p "$STATE_DIR" "$(dirname "$COLORS_OUT")"

list_wallpapers() {
    find "$DIR" -type f \
        \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \
        -o -iname '*.webp' -o -iname '*.avif' \) \
        | sort
}

current_wallpaper() {
    [[ -f "$STATE_FILE" ]] && cat "$STATE_FILE"
}

ensure_matugen_config() {
    mkdir -p "$MATUGEN_DIR/templates"

    if [[ ! -f "$MATUGEN_CONFIG" ]]; then
        sed -i '/^[[:space:]]*wallpaper[[:space:]]*=[[:space:]]*""[[:space:]]*$/d' "$MATUGEN_CONFIG"
        cat > "$MATUGEN_CONFIG" <<EOF
        [config]
        reload_apps = true
        set_wallpaper = false

        [templates.wayck]
        input_path = "$MATUGEN_TEMPLATE"
        output_path = "$COLORS_OUT"
EOF
    fi

    if [[ ! -f "$MATUGEN_TEMPLATE" ]]; then
        echo "Template Matugen não encontrado: $MATUGEN_TEMPLATE" >&2
        return 1
    fi
}

generate_colors() {
    local img="$1"

    ensure_matugen_config

    matugen image "$img" \
        --config "$MATUGEN_CONFIG" \
        --mode "$THEME_MODE" \
        --type "$SCHEME_TYPE" \
        --source-color-index 0
}

set_wallpaper() {
    local img="$1"

    if [[ ! -f "$img" ]]; then
        echo "Wallpaper não encontrado: $img" >&2
        return 1
    fi

    mkdir -p "$STATE_DIR"

    local tmp
    tmp="$(mktemp "$STATE_DIR/wallpaper.XXXXXX")"

    printf '%s\n' "$img" > "$tmp"
    mv -f "$tmp" "$STATE_FILE"

    generate_colors "$img"

    echo "Wallpaper definido: $img"
}

select_relative_wallpaper() {
    local direction="$1"
    local -a wallpapers=()

    mapfile -t wallpapers < <(list_wallpapers)

    if (( ${#wallpapers[@]} == 0 )); then
        echo "Nenhum wallpaper encontrado em: $DIR" >&2
        return 1
    fi

    local current
    current="$(current_wallpaper || true)"

    local index=-1

    for i in "${!wallpapers[@]}"; do
        if [[ "${wallpapers[$i]}" == "$current" ]]; then
            index="$i"
            break
        fi
    done

    if [[ "$direction" == "next" ]]; then
        index=$(( (index + 1) % ${#wallpapers[@]} ))
    else
        if (( index <= 0 )); then
            index=$((${#wallpapers[@]} - 1))
        else
            index=$((index - 1))
        fi
    fi

    set_wallpaper "${wallpapers[$index]}"
}

case "${1:-}" in
    list)
        list_wallpapers
        ;;

    current)
        current_wallpaper
        ;;

    set)
        [[ -n "${2:-}" ]] || {
            echo "Uso: wayck-wallpaper set <imagem>" >&2
            exit 1
        }

        set_wallpaper "$2"
        ;;

    random)
        mapfile -t wallpapers < <(list_wallpapers)

        if (( ${#wallpapers[@]} == 0 )); then
            echo "Nenhum wallpaper encontrado em: $DIR" >&2
            exit 1
        fi

        set_wallpaper "${wallpapers[RANDOM % ${#wallpapers[@]}]}"
        ;;

    next)
        select_relative_wallpaper next
        ;;

    prev|previous)
        select_relative_wallpaper prev
        ;;

    apply)
        img="$(current_wallpaper || true)"

        if [[ -z "$img" || ! -f "$img" ]]; then
            mapfile -t wallpapers < <(list_wallpapers)

            if (( ${#wallpapers[@]} == 0 )); then
                echo "Nenhum wallpaper encontrado em: $DIR" >&2
                exit 1
            fi

            img="${wallpapers[0]}"
        fi

        set_wallpaper "$img"
        ;;

    *)
        echo "Uso: wayck-wallpaper {list|current|set|random|next|prev|apply}" >&2
        exit 1
        ;;
esac
