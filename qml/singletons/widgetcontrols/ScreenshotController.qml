
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../../"

Singleton {
    id: root

    readonly property string directory:
        Quickshell.env("HOME") + "/Pictures/Screenshots"

    readonly property string script: [
        'set -Eeuo pipefail',

        'dir="$1"',
        'mode="$2"',
        'action="$3"',
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
        '    echo "Texto reconhecido e copiado: $file"',
        'else',
        '    wl-copy --type image/png < "$file" || { echo "Falha ao copiar imagem" >&2; exit 1; }',
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
                console.log("[Screenshot]", mode + ":", result || "concluído")

                if (action === "ocr") {
                    NotificationController.send(
                        I18n.t("notifications.ocr.title"),
                        I18n.t("notifications.ocr.body")
                    )
                } else {
                    NotificationController.send(
                        I18n.t("notifications.screenshot.title"),
                        I18n.t("notifications.screenshot.body")
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
