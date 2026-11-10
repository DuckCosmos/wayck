import QtQuick
import QtQuick.Effects
import Quickshell
import "../"

Item {
    id: root

    property alias maskItem: morphCarrier
    property alias sourceHoverItem: sourceHoverRegion

    readonly property bool debug: Quickshell.env("WAYCK_DEBUG") === "1"

    property bool active: false
    property bool opening: false
    property bool closing: false
    property bool revealActive: false
    property bool closeOnHoverExit: true
    property bool sourceHovered: false
    property bool surfaceHovered: false

    property string surfaceId: ""
    property var surfaceData: null
    property var sourceItem: null
    property var snapshotItem: null
    property var hiddenSources: []

    property real sourceX: 0
    property real sourceY: 0
    property real sourceWidth: 0
    property real sourceHeight: 0

    property real progress: 0
    property real snapshotOpacity: 1

    readonly property real contentProgress:
        Math.max(0, Math.min(1, (progress - 0.18) / 0.82))

    readonly property real targetWidth: surfaceId === "tray"
        ? Math.min(
            Math.max(240, surfaceContent.implicitWidth || 256),
            Math.max(1, width - 24)
        )
        : surfaceId === "audio"
            ? Math.min(390, Math.max(300, width - 32))
            : surfaceId === "updater"
                ? Math.min(360, Math.max(300, width - 32))
                : Math.min(460, Math.max(240, width - 48))

    readonly property real targetHeight: surfaceId === "tray"
        ? Math.min(
            Math.max(72, surfaceContent.implicitHeight || 72),
            Math.max(1, height - 24)
        )
        : surfaceId === "audio"
            ? Math.min(300, Math.max(230, height - 32))
            : surfaceId === "updater"
                ? Math.min(220, Math.max(180, height - 32))
                : Math.min(260, Math.max(210, height - 48))

    readonly property real targetX: Math.max(0, Math.min(
        sourceX + sourceWidth / 2 - targetWidth / 2,
        width - targetWidth
    ))

    readonly property real targetY: Math.max(8, Math.min(
        BarConfig.position === "bottom"
            ? sourceY - targetHeight - 8
            : sourceY + sourceHeight + 8,
        height - targetHeight - 8
    ))

    property real animatedTargetX: targetX
    property real animatedTargetY: targetY
    property real animatedTargetWidth: targetWidth
    property real animatedTargetHeight: targetHeight

    readonly property real collapsedRadius: surfaceId === "tray" ? 7 : 9
    readonly property real expandedRadius:
        surfaceId === "tray" ? 14
        : (surfaceId === "audio" || surfaceId === "updater" ? 17 : 20)

    Behavior on animatedTargetX {
        enabled: root.active && root.progress >= 0.98
        NumberAnimation {
            duration: Motion.surfaceRetargetDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.morphCurve
        }
    }

    Behavior on animatedTargetY {
        enabled: root.active && root.progress >= 0.98
        NumberAnimation {
            duration: Motion.surfaceRetargetDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.morphCurve
        }
    }

    Behavior on animatedTargetWidth {
        enabled: root.active && root.progress >= 0.98
        NumberAnimation {
            duration: Motion.surfaceRetargetDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.morphCurve
        }
    }

    Behavior on animatedTargetHeight {
        enabled: root.active && root.progress >= 0.98
        NumberAnimation {
            duration: Motion.surfaceRetargetDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.morphCurve
        }
    }

    onTargetXChanged: animatedTargetX = targetX
    onTargetYChanged: animatedTargetY = targetY
    onTargetWidthChanged: animatedTargetWidth = targetWidth
    onTargetHeightChanged: animatedTargetHeight = targetHeight

    Behavior on snapshotOpacity {
        NumberAnimation {
            duration: Motion.contentFadeDuration
            easing.type: Easing.OutCubic
        }
    }

    Timer {
        id: hoverCloseTimer
        interval: 420
        repeat: false

        onTriggered: {
            if (root.active && !root.closing && root.closeOnHoverExit
                    && !root.surfaceHovered && !root.sourceHovered
                    && root.progress >= 0.98)
                root.close()
        }
    }

    NumberAnimation {
        id: openAnimation
        target: root
        property: "progress"
        to: 1
        duration: Motion.surfaceOpenDuration
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Motion.surfaceOpenCurve

        onFinished: {
            root.opening = false
            root.revealActive = false
            root.evaluateHoverExit()
        }
    }

    NumberAnimation {
        id: closeAnimation
        target: root
        property: "progress"
        to: 0
        duration: Motion.surfaceCloseDuration
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Motion.surfaceCloseCurve

        onFinished: root.finish()
    }

    function log(message): void {
        if (debug)
            console.log("[WAYCK MORPH]", message)
    }

    function hideSourceItem(item, hideVisually): void {
        if (!item)
            return

        for (const entry of hiddenSources) {
            if (entry.item === item)
                return
        }

        const hasHover = "hoverEnabled" in item

        hiddenSources = hiddenSources.concat([{
            item: item,
            opacity: item.opacity,
            enabled: item.enabled,
            hoverEnabled: hasHover ? item.hoverEnabled : false
        }])

        item.enabled = false

        if (hasHover) {
            item.hoverEnabled = false
            item.hovered = false
        }

        if (hideVisually)
            item.opacity = 0
    }

    function restoreSources(): void {
        const entries = hiddenSources
        hiddenSources = []

        for (const entry of entries) {
            const item = entry.item
            if (!item)
                continue

            item.opacity = entry.opacity
            item.enabled = entry.enabled

            if ("hoverEnabled" in item) {
                item.hoverEnabled = entry.hoverEnabled
                item.hovered = false
            }
        }
    }

    function setSource(item): bool {
        if (!item || item.window !== root.window || !item.visible
                || item.width <= 0 || item.height <= 0) {
            log("origem inválida ou fora da janela da barra")
            return false
        }

        const position = item.mapToItem(root, 0, 0)

        sourceX = position.x
        sourceY = position.y
        sourceWidth = Math.max(1, item.width)
        sourceHeight = Math.max(1, item.height)

        sourceItem = item
        hideSourceItem(item, false)

        return true
    }

    function open(item, requestedSurfaceId, data): void {
        if (active || opening)
            return

        if (requestedSurfaceId !== "player"
                && requestedSurfaceId !== "tray"
                && requestedSurfaceId !== "audio"
                && requestedSurfaceId !== "updater") {
            console.warn("[WAYCK MORPH] superfície sem componente:", requestedSurfaceId)
            return
        }

        if (!setSource(item))
            return

        surfaceId = requestedSurfaceId
        surfaceData = data === undefined ? null : data
        snapshotItem = item
        snapshotOpacity = 1

        closeOnHoverExit = true
        sourceHovered = true
        surfaceHovered = false
        closing = false
        opening = true
        revealActive = true
        progress = 0
        active = true

        hoverCloseTimer.stop()
        closeAnimation.stop()
        openAnimation.restart()

        log("morph iniciado: " + surfaceId)
    }

    function setSourceGeometry(item): void {
        const position = item.mapToItem(root, 0, 0)
        sourceX = position.x
        sourceY = position.y
        sourceWidth = Math.max(1, item.width)
        sourceHeight = Math.max(1, item.height)
    }

    function retarget(item, requestedSurfaceId, data): void {
        if (!active || requestedSurfaceId !== "tray" || surfaceId !== "tray")
            return

        if (!item || item.window !== root.window || !item.visible
                || item.width <= 0 || item.height <= 0)
            return

        if (sourceItem === item && surfaceData === data && !closing) {
            sourceHovered = true
            return
        }

        hoverCloseTimer.stop()

        // Keep the first captured texture as the visual source. The new tray
        // anchor becomes the reverse-morph destination and stays hidden until finish.
        hideSourceItem(item, true)
        setSourceGeometry(item)
        sourceItem = item
        surfaceData = data === undefined ? null : data
        sourceHovered = true
        snapshotOpacity = 0

        if (closing) {
            closeAnimation.stop()
            closing = false
            opening = true
            revealActive = true
            openAnimation.restart()
        }

        log("tray retarget")
    }

    function setSurfaceHovered(hovered: bool): void {
        surfaceHovered = hovered

        if (hovered)
            hoverCloseTimer.stop()
        else
            evaluateHoverExit()
    }

    function setSourceHovered(item, hovered: bool): void {
        const sameTrayWindow = surfaceId === "tray"
            && item
            && item.window === root.window

        if (item !== sourceItem && !sameTrayWindow)
            return

        sourceHovered = hovered

        if (hovered)
            hoverCloseTimer.stop()
        else
            evaluateHoverExit()
    }

    function evaluateHoverExit(): void {
        if (active && !closing && closeOnHoverExit
                && !surfaceHovered && !sourceHovered && progress >= 0.98)
            hoverCloseTimer.restart()
    }

    function close(): void {
        if (!active || closing)
            return

        hoverCloseTimer.stop()
        openAnimation.stop()
        opening = false
        closing = true
        revealActive = true
        closeAnimation.restart()

        log("fechando superfície: " + surfaceId)
    }

    function finish(): void {
        hoverCloseTimer.stop()
        openAnimation.stop()
        closeAnimation.stop()

        active = false
        revealActive = false

        restoreSources()

        opening = false
        closing = false
        closeOnHoverExit = true
        sourceHovered = false
        surfaceHovered = false
        progress = 0
        snapshotOpacity = 1
        sourceItem = null
        snapshotItem = null
        surfaceData = null
        surfaceId = ""

        log("morph encerrado")
    }

    Item {
        id: morphContentHost
        anchors.fill: parent
        visible: root.active
        z: 4

        Loader {
            id: surfaceContent

            x: root.targetX
            y: root.targetY
            width: root.targetWidth
            height: root.targetHeight
            visible: root.active
            enabled: root.active && root.progress >= 0.98

            sourceComponent: !root.active
                ? null
                : (root.surfaceId === "tray"
                    ? trayContent
                    : (root.surfaceId === "audio"
                        ? audioContent
                        : (root.surfaceId === "updater"
                            ? updaterContent : playerContent)))

            HoverHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onHoveredChanged: root.setSurfaceHovered(hovered)
            }
        }
    }

    ShaderEffectSource {
        id: contentCapture

        anchors.fill: parent
        sourceItem: morphContentHost
        hideSource: root.revealActive
        live: root.revealActive
        visible: false
    }

    Rectangle {
        id: morphCarrier

        x: root.sourceX + (root.animatedTargetX - root.sourceX) * root.progress
        y: root.sourceY + (root.animatedTargetY - root.sourceY) * root.progress
        width: root.sourceWidth + (root.animatedTargetWidth - root.sourceWidth) * root.progress
        height: root.sourceHeight + (root.animatedTargetHeight - root.sourceHeight) * root.progress
        radius: root.collapsedRadius
            + (root.expandedRadius - root.collapsedRadius) * root.progress

        visible: root.active
        z: 2
        clip: true
        antialiasing: true
        color: Theme.surfaceContainer
        border.width: 1
        border.color: Theme.outline

        ShaderEffectSource {
            id: sourceCapture

            anchors.fill: parent
            sourceItem: root.snapshotItem
            hideSource: root.active
            live: root.active
            visible: root.active && root.snapshotOpacity > 0
            opacity: (1 - root.contentProgress) * root.snapshotOpacity
        }

        MouseArea {
            anchors.fill: parent
            enabled: root.active && root.progress < 0.98
            acceptedButtons: Qt.AllButtons
            hoverEnabled: false

            onPressed: mouse => mouse.accepted = true
            onClicked: mouse => mouse.accepted = true
            onWheel: wheel => wheel.accepted = true
        }

        HoverHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onHoveredChanged: root.setSurfaceHovered(hovered)
        }
    }

    Item {
        id: childRevealMaskItem

        anchors.fill: parent
        visible: false
        layer.enabled: true

        Rectangle {
            x: morphCarrier.x
            y: morphCarrier.y
            width: Math.max(1, morphCarrier.width)
            height: Math.max(1, morphCarrier.height)
            radius: morphCarrier.radius
            color: "white"
        }
    }

    MultiEffect {
        anchors.fill: parent
        source: contentCapture
        visible: root.revealActive
        z: 3
        opacity: root.contentProgress
        maskEnabled: true
        maskSource: childRevealMaskItem
        maskThresholdMin: 0.5
        maskSpreadAtMin: 0.025
        maskThresholdMax: 1.0
        maskSpreadAtMax: 0.0
    }

    Item {
        id: sourceHoverRegion

        x: root.sourceX
        y: root.sourceY
        width: root.surfaceId === "tray" ? 0 : root.sourceWidth
        height: root.surfaceId === "tray" ? 0 : root.sourceHeight
        visible: root.active && root.surfaceId !== "tray"
        z: 5

        HoverHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onHoveredChanged: {
                if (root.sourceItem)
                    root.setSourceHovered(root.sourceItem, hovered)
            }
        }
    }

    Component {
        id: playerContent

        PlayerExpandedSurface {
            onCloseRequested: root.close()
        }
    }

    Component {
        id: trayContent

        TrayExpandedSurface {
            menu: root.surfaceData
            onCloseRequested: root.close()
        }
    }

    Component {
        id: audioContent

        AudioExpandedSurface {
            onCloseRequested: root.close()
        }
    }

    Component {
        id: updaterContent

        UpdateExpandedSurface {
            onUpdateRequested: {
                UpdateController.installUpdate()
                root.close()
            }
            onCloseRequested: root.close()
        }
    }
}
