
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../../"

Singleton {
    id: root

    readonly property bool enabled: Config.soundEffects
    readonly property string notificationSound: Config.notificationSound
    readonly property bool doNotDisturb: Config.doNotDisturb

    readonly property string soundsDir:
        decodeURIComponent(
            Qt.resolvedUrl("../../assets/sounds/").toString()
                .replace("file://", "")
        )

    property var activePlayers: ({})

    readonly property var sounds: ({
        click: {
            file: "reusables/clickbutton/click.wav",
            volume: 0.3
        },

        longCharge: {
            file: "quickactions/usage.wav",
            volume: 0.25
        },

        shortCharge: {
            file: "reusables/fillbutton/charge_loop.wav",
            volume: 0.25
        },

        clickbutton: {
            file: "reusables/toggle/sfx.wav",
            volume: 0.3
        }
    })

    readonly property var notificationSounds: [
        "Botanica.wav",
        "Curious.mp3",
        "Progress.wav",
        "Sine.wav",
        "Sneak.mp3",
        "WakeUp.mp3",
        "Wobbly.mp3"
    ]

    Component {
        id: soundProcess

        Process {
            id: proc

            property string soundName: ""

            stdinEnabled: false

            onExited: {
                if (root.activePlayers[soundName] === proc) {
                    const players = Object.assign(
                        {},
                        root.activePlayers
                    )

                    delete players[soundName]
                    root.activePlayers = players
                }

                proc.destroy()
            }
        }
    }

    function play(name) {
        if (!enabled && name !== "notification")
            return

        if (name === "notification" && doNotDisturb)
            return

        let sound

        if (name === "notification") {
            if (!notificationSounds.includes(notificationSound))
                return

            sound = {
                file: "notifications/" + notificationSound,
                volume: 0.5
            }
        } else {
            sound = sounds[name]
        }

        if (!sound)
            return

        Qt.callLater(() => {
            root.stop(name)

            const path = root.soundsDir + sound.file

            const player = soundProcess.createObject(root, {
                soundName: name,

                command: [
                    "pw-play",
                    "--volume=" + sound.volume,
                    path
                ]
            })

            if (!player)
                return

            const players = Object.assign(
                {},
                root.activePlayers
            )

            players[name] = player
            root.activePlayers = players

            player.running = true
        })
    }

    function stop(name) {
        const player = activePlayers[name]

        if (!player)
            return

        const players = Object.assign(
            {},
            activePlayers
        )

        delete players[name]
        activePlayers = players

        player.running = false
    }

    function stopAll() {
        const players = Object.values(activePlayers)

        activePlayers = ({})

        for (const player of players)
            player.running = false
    }
}
