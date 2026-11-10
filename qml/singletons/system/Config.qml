pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../../"

Singleton {
    id: root

    readonly property string directory:
        (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/wayck"

    readonly property string path: directory + "/config.json"

    readonly property var barDefaults: ({
        left: ["workspaces", "player", "ram", "disk"],
        center: ["cpu", "clock", "gpu", "temperature"],
        right: ["network", "audio", "tray", "usermenu"]
    })

    readonly property bool blur: adapter.blur
    readonly property bool threeDimensionalWave: adapter.threeDimensionalWave
    readonly property string language: adapter.language
    readonly property string notificationSound: adapter.notificationSound
    readonly property bool soundEffects: adapter.soundEffects
    readonly property bool doNotDisturb: adapter.doNotDisturb
    readonly property var bar: adapter.bar

    function setLanguage(code) {
        adapter.language = String(code || "auto")
    }

    FileView {
        path: root.path
        watchChanges: true

        property bool initialLoadHandled: false

        onLoaded: {
            if (initialLoadHandled)
                return

            initialLoadHandled = true
            writeAdapter()
        }

        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()

        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                writeAdapter()
        }

        adapter: JsonAdapter {
            id: adapter

            property bool blur: false
            property bool threeDimensionalWave: true
            property string language: "auto"
            property string notificationSound: "Curious.mp3"
            property bool soundEffects: true
            property bool doNotDisturb: false

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