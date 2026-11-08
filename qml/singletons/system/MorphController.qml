pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    property bool active: false
    property bool closing: false
    property bool closeOnHoverExit: true
    property bool surfaceHovered: false

    // progress is the requested endpoint; animationProgress mirrors the
    // interpolated MorphSurface value so hover-close waits for the open morph.
    property real progress: 0
    property real animationProgress: 0

    property var sourceItem: null
    property var targetScreen: null
    property var grabResult: null
    property var surfaceData: null

    property real sourceGlobalX: 0
    property real sourceGlobalY: 0
    property real sourceWidth: 0
    property real sourceHeight: 0
    property real sourceOpacity: 1
    property string surfaceId: ""

    property int requestSerial: 0

    readonly property url snapshotUrl: grabResult ? grabResult.url : ""

    Timer {
        id: hoverCloseTimer

        interval: 220
        repeat: false

        onTriggered: {
            if (root.active
                    && !root.closing
                    && root.closeOnHoverExit
                    && !root.surfaceHovered
                    && root.animationProgress >= 0.98) {
                root.close()
            }
        }
    }

    function open(item, requestedSurfaceId, data): void {
        if (!item || !item.window || !item.visible)
            return

        if (active)
            return

        if (requestedSurfaceId !== "player" && requestedSurfaceId !== "tray") {
            console.warn("[WAYCK MOTION] superfície expandida não registrada:", requestedSurfaceId)
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
        surfaceData = data === undefined ? null : data
        closing = false
        closeOnHoverExit = true
        surfaceHovered = false
        animationProgress = 0
        progress = 0
        hoverCloseTimer.stop()

        const accepted = item.grabToImage(function(result) {
            if (token !== root.requestSerial || !root.sourceItem)
                return

            if (!result || !result.url) {
                console.warn("[WAYCK MOTION] não foi possível capturar a superfície de origem")
                root.sourceItem = null
                root.targetScreen = null
                root.surfaceData = null
                root.surfaceId = ""
                return
            }

            root.grabResult = result
            root.active = true

            Qt.callLater(function() {
                if (token !== root.requestSerial || !root.active || root.closing || !root.sourceItem)
                    return

                root.sourceItem.opacity = 0
                root.progress = 1
            })
        })

        if (!accepted) {
            console.warn("[WAYCK MOTION] grabToImage recusou a captura da superfície")
            sourceItem = null
            targetScreen = null
            surfaceData = null
            surfaceId = ""
        }
    }

    function setSurfaceHovered(hovered: bool): void {
        surfaceHovered = hovered

        if (hovered) {
            hoverCloseTimer.stop()
        } else {
            evaluateHoverExit()
        }
    }

    function syncAnimationProgress(value: real): void {
        animationProgress = value
        evaluateHoverExit()
    }

    function evaluateHoverExit(): void {
        if (active
                && !closing
                && closeOnHoverExit
                && !surfaceHovered
                && animationProgress >= 0.98) {
            hoverCloseTimer.restart()
        }
    }

    function close(): void {
        if (!active || closing)
            return

        const alreadyCollapsed = animationProgress <= 0.001
        hoverCloseTimer.stop()
        closing = true
        progress = 0

        if (alreadyCollapsed)
            Qt.callLater(root.finish)
    }

    function finish(): void {
        if (sourceItem)
            sourceItem.opacity = sourceOpacity

        hoverCloseTimer.stop()
        ++requestSerial
        active = false
        closing = false
        closeOnHoverExit = true
        surfaceHovered = false
        progress = 0
        animationProgress = 0
        sourceItem = null
        targetScreen = null
        grabResult = null
        surfaceData = null
        surfaceId = ""
    }
}
