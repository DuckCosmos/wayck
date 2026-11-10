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
    property bool sourceHovered: false

    // The endpoint is requested here; MorphSurface reports interpolated progress.
    property real progress: 0
    property real animationProgress: 0

    property var sourceItem: null
    property var targetScreen: null
    property var grabResult: null
    property var surfaceData: null
    property real snapshotOpacity: 1
    property bool morphStarted: false
    property var pendingSourceItem: null
    property real pendingSourceOpacity: 1
    property bool pendingSourceRestore: false

    property real sourceGlobalX: 0
    property real sourceGlobalY: 0
    property real sourceWidth: 0
    property real sourceHeight: 0
    property real sourceOpacity: 1
    property string surfaceId: ""

    property int requestSerial: 0

    readonly property url snapshotUrl: grabResult ? grabResult.url : ""

    Timer {
        id: snapshotFallbackTimer
        interval: 120
        repeat: false
        onTriggered: root.startMorph(root.requestSerial)
    }

    Timer {
        id: hoverCloseTimer
        interval: 420
        repeat: false

        onTriggered: {
            if (root.active && !root.closing && root.closeOnHoverExit
                    && !root.surfaceHovered && !root.sourceHovered
                    && root.animationProgress >= 0.98)
                root.close()
        }
    }

    function log(message): void {
        if (debug)
            console.log("[WAYCK MORPH]", message)
    }

    function startMorph(token): void {
        if (token !== requestSerial || !active || closing || !sourceItem || morphStarted)
            return

        snapshotFallbackTimer.stop()
        morphStarted = true

        // The source is hidden only when the overlay is ready to animate.
        // This prevents the original and the expanded representation from
        // being rendered simultaneously while grabToImage is still pending.
        sourceItem.opacity = 0
        opening = false
        progress = 1

        log("animação iniciada: " + surfaceId
            + (grabResult ? " (snapshot)" : " (sem snapshot)"))
    }

    function open(item, requestedSurfaceId, data, windowRef): void {
        log("open() chamado: " + requestedSurfaceId + " | item=" + !!item)

        if (active || opening) {
            log("pedido ignorado: superfície já ativa")
            return
        }

        // A previous overlay has already been hidden before this point.
        restoreSource()

        if (!item) {
            console.warn("[WAYCK MORPH] origem ausente:", requestedSurfaceId)
            return
        }

        const sourceWindow = windowRef || item.window
        if (!sourceWindow || !sourceWindow.screen || !item.visible
                || item.width <= 0 || item.height <= 0) {
            console.warn("[WAYCK MORPH] origem indisponível:", requestedSurfaceId,
                "window:", !!sourceWindow,
                "screen:", sourceWindow ? !!sourceWindow.screen : false,
                "visible:", item.visible,
                "size:", item.width, "x", item.height)
            return
        }

        if (requestedSurfaceId !== "player"
                && requestedSurfaceId !== "tray"
                && requestedSurfaceId !== "audio"
                && requestedSurfaceId !== "updater") {
            console.warn("[WAYCK MORPH] superfície sem componente:", requestedSurfaceId)
            return
        }

        let localRect
        try {
            localRect = sourceWindow.itemRect(item)
        } catch (error) {
            console.warn("[WAYCK MORPH] QsWindow.itemRect falhou:", error)
            return
        }

        const screen = sourceWindow.screen
        if (!screen || !localRect || localRect.width <= 0 || localRect.height <= 0) {
            console.warn("[WAYCK MORPH] geometria de origem inválida:",
                requestedSurfaceId, "screen:", !!screen, "rect:", localRect)
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
        sourceHovered = true
        surfaceHovered = false
        animationProgress = 0
        progress = 0
        grabResult = null
        snapshotOpacity = 1
        morphStarted = false
        opening = true
        active = true
        hoverCloseTimer.stop()

        log("morph iniciado: " + requestedSurfaceId
            + " | screen=" + screen.name
            + " | rect=" + Math.round(sourceGlobalX) + ","
            + Math.round(sourceGlobalY) + " "
            + Math.round(sourceWidth) + "x" + Math.round(sourceHeight))

        // Wait briefly for the snapshot so the collapsed source and expanded
        // overlay never compete on screen. A timeout keeps opening non-blocking.
        snapshotFallbackTimer.start()

        try {
            const accepted = item.grabToImage(function(result) {
                if (token !== root.requestSerial
                        || !root.active
                        || root.closing
                        || root.sourceItem !== item
                        || root.morphStarted) {
                    return
                }

                if (result && result.url) {
                    root.grabResult = result
                    root.log("snapshot recebido: " + requestedSurfaceId)
                } else {
                    root.log("snapshot indisponível; usando conteúdo do overlay")
                }

                root.startMorph(token)
            })

            log("grabToImage enviado; accepted=" + accepted)
            if (!accepted)
                startMorph(token)
        } catch (error) {
            log("grabToImage falhou; usando conteúdo do overlay: " + error)
            startMorph(token)
        }
    }

    function retarget(item, requestedSurfaceId, data, windowRef): void {
        if (!active || requestedSurfaceId !== "tray" || surfaceId !== "tray")
            return

        if (!item) {
            log("retarget ignorado: âncora ausente")
            return
        }

        const sourceWindow = windowRef || item.window
        if (!sourceWindow || !sourceWindow.screen || !item.visible
                || item.width <= 0 || item.height <= 0) {
            log("retarget ignorado: item indisponível")
            return
        }

        let localRect
        try {
            localRect = sourceWindow.itemRect(item)
        } catch (error) {
            console.warn("[WAYCK MORPH] retarget itemRect falhou:", error)
            return
        }

        const screen = sourceWindow.screen
        if (!screen || !localRect || localRect.width <= 0 || localRect.height <= 0
                || !targetScreen || screen.name !== targetScreen.name) {
            log("retarget ignorado: monitor/geometria incompatível")
            return
        }

        hoverCloseTimer.stop()

        if (sourceItem === item && surfaceData === data && !closing) {
            sourceHovered = true
            return
        }

        // Restore the previous tray icon before changing the anchor. The retained
        // snapshot fades away; the morph itself never collapses or restarts.
        if (sourceItem)
            sourceItem.opacity = sourceOpacity

        sourceItem = item
        sourceOpacity = item.opacity
        sourceGlobalX = screen.x + localRect.x
        sourceGlobalY = screen.y + localRect.y
        sourceWidth = Math.max(1, localRect.width)
        sourceHeight = Math.max(1, localRect.height)
        surfaceData = data === undefined ? null : data
        sourceHovered = true
        snapshotOpacity = 0

        if (closing) {
            closing = false
            opening = false
            progress = 1
        }

        log("tray retarget: " + (data && data.toString ? data.toString() : "menu")
            + " | rect=" + Math.round(sourceGlobalX) + ","
            + Math.round(sourceGlobalY) + " "
            + Math.round(sourceWidth) + "x" + Math.round(sourceHeight))
    }

    function setSurfaceHovered(hovered: bool): void {
        surfaceHovered = hovered

        if (hovered) {
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

    function setSourceHovered(item, hovered: bool): void {
        const sameTrayOutput = surfaceId === "tray"
            && item
            && item.window
            && targetScreen
            && item.window.screen
            && item.window.screen.name === targetScreen.name

        if (item !== sourceItem && !sameTrayOutput)
            return

        sourceHovered = hovered

        if (hovered) {
            hoverCloseTimer.stop()
            log("ponteiro sobre a origem")
        } else {
            log("ponteiro saiu da origem")
            evaluateHoverExit()
        }
    }

    function evaluateHoverExit(): void {
        if (active
                && !closing
                && closeOnHoverExit
                && !surfaceHovered
                && !sourceHovered
                && animationProgress >= 0.98) {
            hoverCloseTimer.restart()
        }
    }

    function close(): void {
        if ((!active && !opening) || closing)
            return

        const alreadyCollapsed = animationProgress <= 0.001
        hoverCloseTimer.stop()
        snapshotFallbackTimer.stop()
        opening = false
        closing = true
        progress = 0

        log("fechando superfície: " + surfaceId)

        if (alreadyCollapsed) {
            Qt.callLater(function() {
                if (root.closing && root.progress <= 0.001)
                    root.finish()
            })
        }
    }

    function restoreSource(): void {
        if (!pendingSourceRestore)
            return

        const item = pendingSourceItem
        const opacity = pendingSourceOpacity

        pendingSourceItem = null
        pendingSourceRestore = false

        if (item)
            item.opacity = opacity

        log("origem restaurada após ocultar overlay")
    }

    function finish(): void {
        hoverCloseTimer.stop()
        snapshotFallbackTimer.stop()
        ++requestSerial

        // Keep the original item hidden until MorphOverlay confirms that its
        // window is no longer visible. This prevents a final compositor frame
        // from showing both the overlay snapshot and the original widget.
        pendingSourceItem = sourceItem
        pendingSourceOpacity = sourceOpacity
        pendingSourceRestore = pendingSourceItem !== null

        active = false

        opening = false
        closing = false
        closeOnHoverExit = true
        surfaceHovered = false
        sourceHovered = false
        progress = 0
        animationProgress = 0
        sourceItem = null
        targetScreen = null
        grabResult = null
        snapshotOpacity = 1
        morphStarted = false
        surfaceData = null
        surfaceId = ""

        log("overlay encerrado; aguardando ocultação antes de restaurar origem")
    }
}
