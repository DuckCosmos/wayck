pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    property bool active: false
    property bool closing: false
    property real progress: 0

    property var sourceItem: null
    property var targetScreen: null
    property var grabResult: null
    property real sourceGlobalX: 0
    property real sourceGlobalY: 0
    property real sourceWidth: 0
    property real sourceHeight: 0
    property real sourceOpacity: 1
    property string surfaceId: ""

    property int requestSerial: 0

    readonly property url snapshotUrl: grabResult ? grabResult.url : ""

    function open(item, requestedSurfaceId): void {
        if (!item || !item.window || !item.visible)
            return

        if (active)
            return

        if (requestedSurfaceId !== "player") {
            console.warn("[WAYCK MOTION] superfície expandida ainda não implementada:", requestedSurfaceId)
            return
        }

        const topLeft = item.mapToGlobal(0, 0)
        const bottomRight = item.mapToGlobal(item.width, item.height)
        const token = ++requestSerial

        sourceItem = item
        targetScreen = item.window.screen
        sourceGlobalX = topLeft.x
        sourceGlobalY = topLeft.y
        sourceWidth = Math.max(1, bottomRight.x - topLeft.x)
        sourceHeight = Math.max(1, bottomRight.y - topLeft.y)
        sourceOpacity = item.opacity
        surfaceId = requestedSurfaceId
        closing = false
        progress = 0

        const accepted = item.grabToImage(function(result) {
            if (token !== root.requestSerial || !root.sourceItem)
                return

            if (!result || !result.url) {
                console.warn("[WAYCK MOTION] não foi possível capturar a superfície de origem")
                root.sourceItem = null
                root.targetScreen = null
                root.surfaceId = ""
                return
            }

            root.grabResult = result
            root.active = true

            Qt.callLater(function() {
                if (token !== root.requestSerial || !root.active || !root.sourceItem)
                    return

                root.sourceItem.opacity = 0
                root.progress = 1
            })
        })

        if (!accepted) {
            console.warn("[WAYCK MOTION] grabToImage recusou a captura da superfície")
            sourceItem = null
            targetScreen = null
            surfaceId = ""
        }
    }

    function close(): void {
        if (!active)
            return

        closing = true
        progress = 0

        if (progress <= 0.001)
            Qt.callLater(root.finish)
    }

    function finish(): void {
        if (sourceItem)
            sourceItem.opacity = sourceOpacity

        ++requestSerial
        active = false
        closing = false
        progress = 0
        sourceItem = null
        targetScreen = null
        grabResult = null
        surfaceId = ""
    }
}
