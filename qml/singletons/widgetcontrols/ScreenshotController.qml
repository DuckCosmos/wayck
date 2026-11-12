
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../../"

Singleton {
    id: root

    readonly property string script: [
        'set -Eeuo pipefail',

        'mode="$1"',
        'action="$2"',

        'command -v xdg-user-dir >/dev/null 2>&1 || { echo "xdg-user-dir não encontrado" >&2; exit 127; }',
        'command -v grim >/dev/null 2>&1 || { echo "grim não encontrado" >&2; exit 127; }',
        'command -v wl-copy >/dev/null 2>&1 || { echo "wl-copy não encontrado" >&2; exit 127; }',

        'if [ "$action" = "ocr" ]; then',
        '    command -v tesseract >/dev/null 2>&1 || { echo "tesseract não encontrado" >&2; exit 127; }',
        'fi',

        'pictures_dir="$(xdg-user-dir PICTURES 2>/dev/null)"',
        '[ -n "$pictures_dir" ] || pictures_dir="$HOME/Pictures"',

        'dir="$pictures_dir/Screenshots"',

        'mkdir -p "$dir" || exit 1',

        'file="$dir/Screenshot from $(date \'+%Y-%m-%d %H-%M-%S\').png"',

        'if [ "$mode" = "region" ]; then',
        '    command -v slurp >/dev/null 2>&1 || { echo "slurp não encontrado" >&2; exit 127; }',
        '    sleep 0.3',
        '    geometry="$(timeout 60 slurp </dev/null)" || { echo "Seleção cancelada" >&2; exit 1; }',
        '    [ -n "$geometry" ] || exit 1',
        '    grim -g "$geometry" "$file" || exit 1',
        'else',
        '    grim "$file" || exit 1',
        'fi',

        'if [ "$action" = "ocr" ]; then',
        '    tesseract "$file" stdout -l por+eng --psm 3 2>/dev/null | wl-copy --type text/plain',
        '    echo "Texto reconhecido e copiado: $file"',
        'else',
        '    wl-copy --type image/png < "$file" || { echo "Falha ao copiar imagem" >&2; exit 1; }',
        '    echo "salvo e copiado: $file"',
        'fi',

        'printf \'WAYCK_FILE_PATH=%s\\n\' "$file"'
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
            mode,
            action
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
                const match = result.match(/^WAYCK_FILE_PATH=(.*)$/m)
                const filePath = match ? match[1] : ""

                console.log("[Screenshot]", mode + ":", result)

                if (action === "ocr") {
                    NotificationController.send(
                        I18n.t("notifications.ocr.title"),
                        I18n.t("notifications.ocr.body"),
                        filePath
                    )
                } else {
                    NotificationController.send(
                        I18n.t("notifications.screenshot.title"),
                        I18n.t("notifications.screenshot.body"),
                        filePath
                    )
                }
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
