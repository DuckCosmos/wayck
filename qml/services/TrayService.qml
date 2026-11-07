pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.SystemTray

Singleton {
    id: root

    property var items: []

    function refresh() {
        items = SystemTray.items.values.slice()
    }

    Connections {
        target: SystemTray.items

        function onObjectInsertedPost(object, index) {
            Qt.callLater(root.refresh)
        }

        function onObjectRemovedPost(object, index) {
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