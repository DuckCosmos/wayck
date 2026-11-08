pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Singleton {
    id: root

    property var players: []
    property var activePlayer: null

    function refresh() {
        const current = Mpris.players.values.slice()
        players = current

        let selected = null
        for (const player of current) {
            if (player.isPlaying) {
                selected = player
                break
            }
        }

        if (!selected && current.length > 0)
            selected = current[0]

        activePlayer = selected
    }

    Connections {
        target: Mpris.players

        function onObjectInsertedPost(object, index) {
            Qt.callLater(root.refresh)
        }

        function onObjectRemovedPost(object, index) {
            Qt.callLater(root.refresh)
        }
    }

    Connections {
        target: root.activePlayer
        ignoreUnknownSignals: true

        function onIsPlayingChanged() {
            Qt.callLater(root.refresh)
        }
    }

    Timer {
        interval: 1500
        repeat: true
        running: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: Qt.callLater(root.refresh)
}
