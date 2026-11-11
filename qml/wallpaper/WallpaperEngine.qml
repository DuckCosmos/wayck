
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

Variants {
    model: Quickshell.screens

    delegate: PanelWindow {
        id: wallpaperWindow

        required property var modelData
        screen: modelData

        readonly property string stateHome:
            Quickshell.env("XDG_STATE_HOME") ||
            (Quickshell.env("HOME") + "/.local/state")

        readonly property string wallpaperStateFile:
            stateHome + "/wayck/wallpaper"

        property string wallpaperPath: ""

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        visible: true
        focusable: false
        aboveWindows: false
        exclusiveZone: -1
        color: "#000000"

        WlrLayershell.namespace: "wayck-wallpaper"
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.exclusiveZone: -1
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        FileView {
            path: wallpaperWindow.wallpaperStateFile
            watchChanges: true

            onFileChanged: reload()

            onLoaded: {
                const nextPath = text().trim()

                if (nextPath.length > 0 &&
                    nextPath !== wallpaperWindow.wallpaperPath) {
                    wallpaperWindow.wallpaperPath = nextPath
                }
            }

            onLoadFailed: error => {
                console.warn(
                    "[WallpaperEngine] Erro ao ler wallpaper:",
                    error
                )
            }
        }

        Image {
            anchors.fill: parent

            source: wallpaperWindow.wallpaperPath.length > 0
                ? "file://" + wallpaperWindow.wallpaperPath
                : ""

            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            smooth: true

            onStatusChanged: {
                if (status === Image.Error)
                    console.warn("[WallpaperEngine] Falha ao carregar:", source)
            }
        }
    }
}
