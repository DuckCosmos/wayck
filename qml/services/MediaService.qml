pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Singleton {
    id: root

    // Snapshot próprio para que a UI reaja à entrada e saída de players.
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
        console.log("[MediaService] players:", current.length,
                    "active:", selected ? selected.identity : "none")
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

    // Fallback leve para players que atualizam o estado sem inserir/remover objetos.
    Timer {
        interval: 1500
        repeat: true
        running: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: Qt.callLater(root.refresh)
}
