pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../../"

Singleton {
    id: root

    property bool updateAvailable: false
    property bool checking: false
    property bool installing: false
    property string localVersion: ""
    property string remoteVersion: ""
    property string error: ""
    property string lastNotifiedVersion: ""

    readonly property string backend: Quickshell.shellPath("wayck-backend")
    readonly property string installerPath: Quickshell.shellPath("install.sh")

    function check(): void {
        if (checking || installing)
            return

        checking = true
        versionProcess.running = true
    }

    function installUpdate(): void {
        console.log("[WAYCK UPDATE] install requested")
        console.log("[WAYCK UPDATE] available:", updateAvailable)
        console.log("[WAYCK UPDATE] installing:", installing)
        console.log("[WAYCK UPDATE] installer:", installerPath)

        if (installing || !updateAvailable) {
            console.warn("[WAYCK UPDATE] installation blocked")
            return
        }

        installing = true
        error = ""

        console.log("[WAYCK UPDATE] executing installer")

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

                    if (root.updateAvailable) {
                        console.log("[WAYCK UPDATE] update available:",
                            root.localVersion, "->", root.remoteVersion)

                        if (root.remoteVersion.length > 0
                                && root.remoteVersion !== root.lastNotifiedVersion) {
                            NotificationController.send(
                                I18n.t("notifications.update.title"),
                                I18n.t("notifications.update.body", {
                                    version: root.remoteVersion
                                })
                            )
                            root.lastNotifiedVersion = root.remoteVersion
                        }
                    } else {
                        root.lastNotifiedVersion = ""
                    }
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
