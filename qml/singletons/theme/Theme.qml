pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Fonte ÚNICA de cores do Wayck.
// Lê a paleta gerada pelo matugen e recarrega sozinho quando o arquivo muda
// (trocou o wallpaper => a barra, o launcher e o clipboard mudam juntos).
//
// Pra mudar o visual do projeto inteiro, mexa só aqui:
//   - os valores "fallback" (usados se o matugen não existir)
//   - qual chave do JSON cada cor semântica usa
Singleton {
    id: root

    readonly property string colorsPath:
        Quickshell.env("HOME") + "/.local/state/quickshell/user/generated/colors.json"

    // JSON cru do matugen. Quando ele é trocado inteiro, todos os
    // bindings abaixo reavaliam automaticamente.
    property var raw: ({})

    function pick(key, fallback) {
        const value = raw[key]
        return value ? value : fallback
    }

    // ---- Cores semânticas (use sempre essas, nunca o JSON direto) ----
    readonly property color primary:          pick("primary", "#ffb59b")
    readonly property color onPrimary:        pick("on_primary", "#55200a")
    readonly property color surfaceContainer: pick("surface_container_high", "#322824")
    readonly property color onSurface:        pick("on_surface", "#f1dfd9")
    readonly property color outline:          pick("outline", "#a08d86")

    FileView {
        path: root.colorsPath
        watchChanges: true

        onFileChanged: reload()

        onLoaded: {
            try {
                root.raw = JSON.parse(text())
            } catch (e) {
                console.warn("[Theme] colors.json inválido:", e)
            }
        }
    }
}
