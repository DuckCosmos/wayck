pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Configuração ÚNICA do Wayck: ~/.config/wayck/config.json
//
//   {
//     "blur": false,
//     "bar": {
//       "position": "top",          // "top" | "bottom"
//       "height": 45,
//       "margin": 8,
//       "layout": { "left": [...], "center": [...], "right": [...] }
//     }
//   }
//
// - Arquivo ausente: é criado com os padrões.
// - Chave ausente: usa o padrão daqui (o install.sh só mexe em "blur").
// - Editou o arquivo na mão: o Wayck recarrega sozinho.
Singleton {
    id: root

    readonly property string directory:
        (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/wayck"

    readonly property string path: directory + "/config.json"

    // Layout padrão da barra (usado no 1º start e no BarConfig.reset()).
    readonly property var barDefaults: ({
        left: ["workspaces", "player", "ram", "disk"],
        center: ["cpu", "clock", "gpu", "temperature"],
        right: ["network", "audio", "tray", "usermenu"]
    })

    // Atalhos de leitura. Pra gravar: Config.bar.position = "bottom" (salva sozinho).
    readonly property bool blur: adapter.blur
    readonly property var bar: adapter.bar

    FileView {
        path: root.path
        watchChanges: true

        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()

        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                writeAdapter()
        }

        adapter: JsonAdapter {
            id: adapter

            property bool blur: false

            property JsonObject bar: JsonObject {
                property string position: "top"
                property int height: 45
                property int margin: 8

                property JsonObject layout: JsonObject {
                    property var left: root.barDefaults.left
                    property var center: root.barDefaults.center
                    property var right: root.barDefaults.right
                }
            }
        }
    }
}
