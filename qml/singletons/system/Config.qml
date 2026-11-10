
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

    readonly property bool gamer: adapter.gamer
    readonly property bool blur: adapter.blur
    readonly property string language: adapter.language
    readonly property string notificationSound: adapter.notificationSound
    readonly property bool soundEffects: adapter.soundEffects
    readonly property bool doNotDisturb: adapter.doNotDisturb
    readonly property var bar: adapter.bar

    function setLanguage(code) {
        adapter.language = String(code || "auto")
    }

    function setBlur(value: bool): void {
        adapter.blur = value
    }

    function setSoundEffects(value: bool): void {
        adapter.soundEffects = value
    }

    function setNotificationSound(value: string): void {
        adapter.notificationSound = value
    }

    function setDoNotDisturb(value: bool): void {
        adapter.doNotDisturb = value
    }

    function setGamer(value: bool): void {
        adapter.gamer = value
    }

    function writeConfig(): void {
        const data = {
            language: adapter.language,
            gamer: adapter.gamer,
            blur: adapter.blur,
            notificationSound: adapter.notificationSound,
            soundEffects: adapter.soundEffects,
            doNotDisturb: adapter.doNotDisturb,

            bar: {
                position: adapter.bar.position,
                height: adapter.bar.height,
                margin: adapter.bar.margin,

                layout: {
                    left: adapter.bar.layout.left,
                    center: adapter.bar.layout.center,
                    right: adapter.bar.layout.right
                }
            }
        }

        file.setText(JSON.stringify(data, null, 4))
    }

    FileView {
        id: file

        path: root.path
        watchChanges: true

        property bool initialLoadHandled: false

        onLoaded: {
            if (initialLoadHandled)
                return

            initialLoadHandled = true
            root.writeConfig()
        }

        onFileChanged: reload()
        onAdapterUpdated: root.writeConfig()

        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                root.writeConfig()
        }

        adapter: JsonAdapter {
            id: adapter

            property bool gamer: false
            property bool blur: false
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
