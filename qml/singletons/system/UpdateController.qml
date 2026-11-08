pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool updateAvailable: false
    property bool checking: false
    property bool installing: false
    property string localVersion: ""
    property string remoteVersion: ""
    property string error: ""

    readonly property string backend: Quickshell.shellPath("wayck-backend")
    readonly property string dataHome: Quickshell.env("XDG_DATA_HOME")
        || (Quickshell.env("HOME") + "/.local/share")
    readonly property string sourceDirectory: dataHome + "/wayck-src"
    readonly property string installerPath: sourceDirectory + "/install.sh"

    function check(): void {
        if (checking || installing)
            return

        checking = true
        versionProcess.running = true
    }

    function installUpdate(): void {
        if (installing || !updateAvailable)
            return

        installing = true
        error = ""

        console.log("[WAYCK UPDATE] starting interactive-free update")

        Quickshell.execDetached([
            "bash",
            installerPath,
            "--update-only"
        ])
    }

    Timer {
        interval: 1300
        repeat: false
        running: true
        onTriggered: root.check()
    }

    Timer {
        interval: 45 * 60 * 1000
        repeat: true
        running: true
        onTriggered: root.check()
    }

    Process {
        id: versionProcess
        command: [root.backend, "--version_info"]

        stdout: StdioCollector {
            id: versionOutput

            onStreamFinished: {
                try {
                    const data = JSON.parse(versionOutput.text.trim())
                    root.localVersion = data.local || ""
                    root.remoteVersion = data.remote || ""
                    root.updateAvailable = data.available === true
                    root.error = ""

                    if (root.updateAvailable)
                        console.log("[WAYCK UPDATE] update available:",
                            root.localVersion, "->", root.remoteVersion)
                } catch (error) {
                    root.error = "Resposta de versão inválida"
                    console.warn("[WAYCK UPDATE] invalid version response:", error)
                }
            }
        }

        stderr: StdioCollector {
            id: versionErrors
        }

        onExited: exitCode => {
            root.checking = false

            if (exitCode !== 0) {
                root.updateAvailable = false
                root.error = versionErrors.text.trim()
                if (root.error.length > 0)
                    console.warn("[WAYCK UPDATE] check failed:", root.error)
            }
        }
    }
}
