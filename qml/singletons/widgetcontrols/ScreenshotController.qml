
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../../"

Singleton {
    id: root

    readonly property string directory:
        Quickshell.env("HOME") + "/Pictures/Screenshots"

    // Cor atual do Matugen
    readonly property string notificationColor: {
        const c = Theme.primary

        const hex = value => {
            const result = Math.round(value * 255).toString(16)
            return result.length === 1 ? "0" + result : result
        }

        return `#${hex(c.r)}${hex(c.g)}${hex(c.b)}`
    }

    readonly property string script: [
        'set -Eeuo pipefail',

        'dir="$1"',
        'mode="$2"',
        'action="$3"',
        'notification_color="$4"',

        '[[ "$notification_color" =~ ^#[[:xdigit:]]{6}$ ]] || notification_color="#444444"',

        // Notificações
        'notify() {',
        '    command -v notify-send >/dev/null 2>&1 || return 0',
        '',
        '    local source_icon="/usr/share/icons/Papirus/22x22/actions/stock_bell.svg"',
        '    local icon_dir="${XDG_CACHE_HOME:-$HOME/.cache}/wayck"',
        '    local color_hex="${notification_color:1}"',
        '    local icon="$icon_dir/notification-bell-${color_hex}.svg"',
        '    local tmp="$icon.tmp.$$"',
        '',
        '    if [ -r "$source_icon" ]; then',
        '        mkdir -p "$icon_dir" || return 0',
        '',
        '        if [ ! -s "$icon" ]; then',
        '            if ! sed "s/#444444/${notification_color}/g" "$source_icon" > "$tmp"; then',
        '                rm -f "$tmp"',
        '                return 0',
        '            fi',
        '',
        '            mv "$tmp" "$icon" || { rm -f "$tmp"; return 0; }',
        '        fi',
        '',
        '        notify-send --app-name="Wayck" --app-icon="$icon" --expire-time=5000 "$1" "$2" || true',
        '    else',
        '        notify-send --app-name="Wayck" --expire-time=5000 "$1" "$2" || true',
        '    fi',
        '}',

        // Dependências
        'command -v grim >/dev/null 2>&1 || { echo "grim não encontrado" >&2; exit 127; }',
        'command -v wl-copy >/dev/null 2>&1 || { echo "wl-copy não encontrado" >&2; exit 127; }',

        'if [ "$action" = "ocr" ]; then',
        '    command -v tesseract >/dev/null 2>&1 || { echo "tesseract não encontrado" >&2; exit 127; }',
        'fi',

        // Diretório
        'mkdir -p "$dir" || exit 1',

        'file="$dir/Screenshot from $(date \'+%Y-%m-%d %H-%M-%S\').png"',

        // Captura
        'if [ "$mode" = "region" ]; then',
        '    command -v slurp >/dev/null 2>&1 || { echo "slurp não encontrado" >&2; exit 127; }',
        '    sleep 0.3',
        '    geometry="$(timeout 60 slurp </dev/null)" || { echo "Seleção cancelada" >&2; exit 1; }',
        '    [ -n "$geometry" ] || exit 1',
        '    grim -g "$geometry" "$file" || exit 1',
        'else',
        '    grim "$file" || exit 1',
        'fi',

        // OCR ou cópia da imagem
        'if [ "$action" = "ocr" ]; then',
        '    tesseract "$file" stdout -l por+eng --psm 3 2>/dev/null | wl-copy --type text/plain',
        '    notify "Texto copiado" "Texto reconhecido e copiado para a área de transferência."',
        '    echo "Texto reconhecido e copiado: $file"',
        'else',
        '    wl-copy --type image/png < "$file" || { echo "Falha ao copiar imagem" >&2; exit 1; }',
        '    notify "Captura de tela" "Imagem salva e copiada: $(basename "$file")"',
        '    echo "salvo e copiado: $file"',
        'fi'
    ].join("\n")

    function full(): void {
        capture("full")
    }

    function region(): void {
        capture("region")
    }

    function regionOCR(): void {
        capture("region", true)
    }

    function capture(mode: string, ocr = false): void {
        if (job.running) {
            console.log("[Screenshot] já existe uma captura em andamento")
            return
        }

        console.log("[Screenshot] iniciando:", mode, ocr ? "OCR" : "imagem")

        job.mode = mode
        job.action = ocr ? "ocr" : "image"
        job.running = true
    }

    Process {
        id: job

        property string mode: "full"
        property string action: "image"

        command: [
            "bash",
            "-c",
            root.script,
            "wayck-screenshot",
            root.directory,
            mode,
            action,
            root.notificationColor
        ]

        stdout: StdioCollector {
            id: output
        }

        stderr: StdioCollector {
            id: errors
        }

        onExited: exitCode => {
            const result = output.text.trim()
            const problem = errors.text.trim()

            if (exitCode === 0) {
                console.log("[Screenshot]", mode + ":", result || "concluído")
            } else {
                console.warn(
                    "[Screenshot] falhou (" + mode + ", código " + exitCode + "):",
                    problem || result
                )
            }
        }
    }

    IpcHandler {
        target: "screenshot"

        function full(): void {
            root.full()
        }

        function region(): void {
            root.region()
        }

        function regionOCR(): void {
            root.regionOCR()
        }
    }
}
