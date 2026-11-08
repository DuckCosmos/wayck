pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    readonly property bool debug: Quickshell.env("WAYCK_DEBUG") === "1"

    property bool active: false
    property bool opening: false
    property bool closing: false
    property bool closeOnHoverExit: true
    property bool surfaceHovered: false
    property bool surfaceWasHovered: false

    // The endpoint is requested here; MorphSurface reports interpolated progress.
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

        interval: 260
        repeat: false

        onTriggered: {
            if (root.active
                    && !root.closing
                    && root.closeOnHoverExit
                    && root.surfaceWasHovered
                    && !root.surfaceHovered
                    && root.animationProgress >= 0.98) {
                root.close()
            }
        }
    }

    function log(message): void {
        if (debug)
            console.log("[WAYCK MORPH]", message)
    }

    function activate(token, result): void {
        if (token !== requestSerial || !sourceItem)
            return

        grabResult = result && result.url ? result : null
        opening = false
        active = true

        log("overlay ativo: " + surfaceId
            + (grabResult ? " (snapshot)" : " (fallback sem snapshot)"))

        Qt.callLater(function() {
            if (token !== root.requestSerial
                    || !root.active
                    || root.closing
                    || !root.sourceItem) {
                return
            }

            // Keep the source visible if capture failed; the overlay still opens.
            if (root.grabResult)
                root.sourceItem.opacity = 0

            root.progress = 1
        })
    }

    function open(item, requestedSurfaceId, data, windowRef): void {
        log("open() chamado: " + requestedSurfaceId + " item=" + !!item)

        if (active || opening) {
            log("pedido ignorado: já existe uma superfície ativa")
            return
        }

        if (!item) {
            console.warn("[WAYCK MORPH] origem ausente:", requestedSurfaceId)
            return
        }

        const sourceWindow = windowRef || item.window

        log("open() recebido: " + requestedSurfaceId
            + " window=" + !!sourceWindow
            + " visible=" + item.visible
            + " rect=" + item.width + "x" + item.height)

        if (!sourceWindow || !item.visible || item.width <= 0 || item.height <= 0) {
            console.warn("[WAYCK MORPH] origem indisponível:", requestedSurfaceId,
                "window:", !!sourceWindow,
                "visible:", item.visible,
                "size:", item.width, "x", item.height)
            return
        }

        if (requestedSurfaceId !== "player" && requestedSurfaceId !== "tray") {
            console.warn("[WAYCK MORPH] superfície expandida não registrada:", requestedSurfaceId)
            return
        }

        const screen = sourceWindow.screen
        let localRect = null

        try {
            localRect = sourceWindow.itemRect(item)
        } catch (error) {
            console.warn("[WAYCK MORPH] QsWindow.itemRect falhou:", error)
            return
        }

        if (!screen || !localRect || localRect.width <= 0 || localRect.height <= 0) {
            console.warn("[WAYCK MORPH] geometria inválida:", requestedSurfaceId,
                "screen:", !!screen,
                "rect:", localRect ? localRect.x + "," + localRect.y + " "
                    + localRect.width + "x" + localRect.height : "null")
            return
        }

        const token = ++requestSerial

        sourceItem = item
        targetScreen = screen
        sourceGlobalX = screen.x + localRect.x
        sourceGlobalY = screen.y + localRect.y
        sourceWidth = Math.max(1, localRect.width)
        sourceHeight = Math.max(1, localRect.height)
        sourceOpacity = item.opacity

        surfaceId = requestedSurfaceId
        surfaceData = data === undefined ? null : data
        closing = false
        closeOnHoverExit = true
        surfaceHovered = false
        surfaceWasHovered = false
        animationProgress = 0
        progress = 0
        grabResult = null
        opening = true
        hoverCloseTimer.stop()

        log("pedido recebido: " + requestedSurfaceId
            + " monitor=" + screen.name
            + " rect=" + Math.round(sourceGlobalX) + ","
            + Math.round(sourceGlobalY) + " "
            + Math.round(sourceWidth) + "x" + Math.round(sourceHeight))

        let accepted = false

        try {
            accepted = item.grabToImage(function(result) {
                if (token !== root.requestSerial || !root.sourceItem)
                    return

                if (!result || !result.url) {
                    console.warn("[WAYCK MORPH] captura falhou; abrindo sem snapshot")
                    root.activate(token, null)
                    return
                }

                root.activate(token, result)
            })
        } catch (error) {
            console.warn("[WAYCK MORPH] erro ao capturar origem:", error)
        }

        if (!accepted) {
            console.warn("[WAYCK MORPH] grabToImage recusou a captura; abrindo sem snapshot")
            activate(token, null)
        }
    }

    function setSurfaceHovered(hovered: bool): void {
        surfaceHovered = hovered

        if (hovered) {
            surfaceWasHovered = true
            hoverCloseTimer.stop()
            log("ponteiro entrou na superfície")
        } else {
            log("ponteiro saiu da superfície")
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
                && surfaceWasHovered
                && !surfaceHovered
                && animationProgress >= 0.98) {
            hoverCloseTimer.restart()
        }
    }

    function close(): void {
        if ((!active && !opening) || closing)
            return

        const alreadyCollapsed = animationProgress <= 0.001
        hoverCloseTimer.stop()
        opening = false
        closing = true
        progress = 0

        log("fechando superfície: " + surfaceId)

        if (alreadyCollapsed)
            Qt.callLater(root.finish)
    }

    function finish(): void {
        if (sourceItem)
            sourceItem.opacity = sourceOpacity

        hoverCloseTimer.stop()
        ++requestSerial
        active = false
        opening = false
        closing = false
        closeOnHoverExit = true
        surfaceHovered = false
        surfaceWasHovered = false
        progress = 0
        animationProgress = 0
        sourceItem = null
        targetScreen = null
        grabResult = null
        surfaceData = null
        surfaceId = ""

        log("superfície liberada")
    }
}
