import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Controls
import Quickshell.Services.Pipewire
import Quickshell
import "../"
import "../bar/faces/tray"

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

            x: root.animatedTargetX
            y: root.animatedTargetY
            width: root.animatedTargetWidth
            height: root.animatedTargetHeight
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
        Item {
            id: expandedRoot

    property var player: MprisController.activePlayer

    signal closeRequested()

    RowLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 22

        Rectangle {
            Layout.preferredWidth: 172
            Layout.preferredHeight: 172
            radius: 14
            color: Theme.surface
            clip: true

            Image {
                anchors.fill: parent
                source: expandedRoot.player ? expandedRoot.player.trackArtUrl : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: expandedRoot.player !== null && expandedRoot.player.trackArtUrl !== ""
            }

            Text {
                anchors.centerIn: parent
                text: "♫"
                color: Theme.primary
                font.pixelSize: 54
                visible: !expandedRoot.player || !expandedRoot.player.trackArtUrl
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 22

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: expandedRoot.player ? (expandedRoot.player.identity || I18n.t("player.title")) : I18n.t("player.none")
                    color: Theme.outline
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "×"
                    color: Theme.surfaceForeground
                    font.pixelSize: 22

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -8
                        onClicked: expandedRoot.closeRequested()
                        cursorShape: Qt.PointingHandCursor
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: expandedRoot.player
                    ? (expandedRoot.player.trackTitle || I18n.t("player.title"))
                    : I18n.t("player.none")
                color: Theme.surfaceForeground
                font.pixelSize: 19
                font.bold: true
                elide: Text.ElideRight
                maximumLineCount: 2
                wrapMode: Text.Wrap
            }

            Text {
                Layout.fillWidth: true
                text: expandedRoot.player
                    ? (expandedRoot.player.trackArtist || I18n.t("player.unknownArtist"))
                    : I18n.t("player.waiting")
                color: Theme.outline
                font.pixelSize: 13
                elide: Text.ElideRight
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 26

                Text {
                    text: "‹"
                    color: expandedRoot.player && expandedRoot.player.canGoPrevious ? Theme.surfaceForeground : Theme.outline
                    font.pixelSize: 34

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -10
                        enabled: expandedRoot.player !== null && expandedRoot.player.canGoPrevious
                        onClicked: expandedRoot.player.previous()
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 46
                    Layout.preferredHeight: 46
                    radius: 23
                    color: Theme.primary

                    Text {
                        anchors.centerIn: parent
                        text: expandedRoot.player && expandedRoot.player.isPlaying ? "Ⅱ" : "▶"
                        color: Theme.onPrimary
                        font.pixelSize: 18
                        font.bold: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: expandedRoot.player !== null && expandedRoot.player.canTogglePlaying
                        onClicked: expandedRoot.player.togglePlaying()
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    }
                }

                Text {
                    text: "›"
                    color: expandedRoot.player && expandedRoot.player.canGoNext ? Theme.surfaceForeground : Theme.outline
                    font.pixelSize: 34

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -10
                        enabled: expandedRoot.player !== null && expandedRoot.player.canGoNext
                        onClicked: expandedRoot.player.next()
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    }
                }
            }
        }
    }
            onCloseRequested: root.close()
        }
    }
    Component {
        id: trayContent
        Item {
            id: expandedRoot

    property var menu: root.surfaceData

    signal closeRequested()

    implicitWidth: menuCard.implicitWidth
    implicitHeight: menuCard.implicitHeight

    TrayMenu {
        id: menuCard

        anchors.left: parent.left
        anchors.top: parent.top

        menu: expandedRoot.menu
        onCloseRequested: root.close()
    }
            onCloseRequested: root.close()
        }
    }
    Component {
        id: audioContent
        Item {
            id: expandedRoot

    signal closeRequested()

    property var trackedNodes: []

    readonly property var audioStreams: trackedNodes.filter(function(node) {
        if (!node || !node.isStream || !node.audio)
            return false

        const props = node.properties || ({})
        const mediaClass = props["media.class"] || ""
        return mediaClass === "" || mediaClass === "Stream/Output/Audio"
    })

    implicitWidth: 360
    implicitHeight: 280

    function refreshNodes(): void {
        trackedNodes = Pipewire.nodes.values
    }

    function appName(node): string {
        const props = node && node.properties ? node.properties : ({})
        return props["application.name"]
            || props["application.process.binary"]
            || node.description
            || node.name
            || I18n.t("audioMixer.appFallback")
    }

    function streamDescription(node): string {
        const props = node && node.properties ? node.properties : ({})
        return props["media.name"]
            || props["media.title"]
            || props["window.title"]
            || node.name
            || I18n.t("audioMixer.streamFallback")
    }

    PwObjectTracker {
        objects: expandedRoot.trackedNodes
    }

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    Connections {
        target: Pipewire.nodes
        ignoreUnknownSignals: true
        function onValuesChanged() { expandedRoot.refreshNodes() }
        function onObjectInsertedPost() { expandedRoot.refreshNodes() }
        function onObjectRemovedPost() { expandedRoot.refreshNodes() }
    }

    Component.onCompleted: refreshNodes()

    Rectangle {
        anchors.fill: parent
        radius: 16
        color: Qt.alpha(Theme.surfaceContainer, 0.98)
        border.width: 1
        border.color: Theme.outline
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 17
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    text: I18n.t("audioMixer.title")
                    color: Theme.surfaceForeground
                    font.pixelSize: 11
                    font.bold: true
                    font.letterSpacing: 0.8
                }

                Text {
                    text: I18n.t("audioMixer.streams", { count: expandedRoot.audioStreams.length })
                    color: Theme.outline
                    font.pixelSize: 10
                }
            }

            Text {
                text: "×"
                color: Theme.outline
                font.pixelSize: 20

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -7
                    onClicked: expandedRoot.closeRequested()
                    cursorShape: Qt.PointingHandCursor
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Theme.outline
            opacity: 0.22
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 5

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: I18n.t("audioMixer.masterVolume")
                    color: Theme.surfaceForeground
                    font.pixelSize: 11
                    font.bold: true
                }

                Item {
                    Layout.fillWidth: true
                }

                Text {
                    text: Pipewire.defaultAudioSink?.audio
                        ? Math.round(Pipewire.defaultAudioSink.audio.volume * 100) + "%"
                        : "--%"
                    color: Theme.outline
                    font.pixelSize: 10
                }
            }

            Slider {
                id: masterVolumeSlider

                Layout.fillWidth: true
                from: 0
                to: 1.5

                enabled: !!Pipewire.defaultAudioSink?.audio

                value: Pipewire.defaultAudioSink?.audio
                    ? Pipewire.defaultAudioSink.audio.volume
                    : 0

                onMoved: {
                    const sink = Pipewire.defaultAudioSink

                    if (!sink?.audio)
                        return

                    sink.audio.volume = value

                    if (value > 0)
                        sink.audio.muted = false
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                id: streamList
                anchors.fill: parent
                clip: true
                spacing: 6
                model: expandedRoot.audioStreams
                boundsBehavior: Flickable.StopAtBounds

                add: Transition {
                    ParallelAnimation {
                        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Motion.contentFadeDuration }
                        NumberAnimation { property: "y"; from: 12; duration: Motion.menuContentDuration; easing.type: Motion.standard }
                    }
                }

                displaced: Transition {
                    NumberAnimation {
                        properties: "x,y"
                        duration: Motion.menuContentDuration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Motion.layoutCurve
                    }
                }

                delegate: Item {
                    id: streamDelegate
                    required property var modelData
                    required property int index

                    property var node: modelData
                    readonly property var props: node && node.properties ? node.properties : ({})
                    readonly property bool muted: node && node.audio ? node.audio.muted : false
                    readonly property real volume: node && node.audio ? node.audio.volume : 0

                    width: streamList.width
                    height: 54

                    RowLayout {
                        anchors.fill: parent
                        spacing: 9

                        Rectangle {
                            Layout.preferredWidth: 34
                            Layout.preferredHeight: 34
                            radius: 10
                            color: Qt.alpha(Theme.primary, 0.14)

                            Text {
                                anchors.centerIn: parent
                                text: "♫"
                                color: Theme.primary
                                font.pixelSize: 17
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 5

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    Text {
                                        Layout.fillWidth: true
                                        text: expandedRoot.appName(streamDelegate.node)
                                        color: Theme.surfaceForeground
                                        font.pixelSize: 11
                                        font.bold: true
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: expandedRoot.streamDescription(streamDelegate.node)
                                        color: Theme.outline
                                        font.pixelSize: 9
                                        elide: Text.ElideRight
                                    }
                                }

                                Text {
                                    text: Math.round(streamDelegate.volume * 100) + "%"
                                    color: Theme.outline
                                    font.pixelSize: 10
                                }
                            }

                            Slider {
                                id: volumeSlider
                                Layout.fillWidth: true
                                Layout.preferredHeight: 15
                                from: 0
                                to: 1.5
                                value: streamDelegate.volume

                                onMoved: {
                                    if (!streamDelegate.node || !streamDelegate.node.audio)
                                        return
                                    streamDelegate.node.audio.volume = value
                                    if (value > 0)
                                        streamDelegate.node.audio.muted = false
                                }

                                background: Rectangle {
                                    x: volumeSlider.leftPadding
                                    y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                                    width: volumeSlider.availableWidth
                                    height: 4
                                    radius: 2
                                    color: Qt.darker(Theme.surfaceContainer, 1.5)

                                    Rectangle {
                                        width: parent.width * volumeSlider.visualPosition
                                        height: parent.height
                                        radius: parent.radius
                                        color: Theme.primary
                                    }
                                }

                                handle: Rectangle {
                                    x: volumeSlider.leftPadding
                                        + volumeSlider.visualPosition * (volumeSlider.availableWidth - width)
                                    y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                                    width: 11
                                    height: 11
                                    radius: 6
                                    color: Theme.primary
                                    border.width: 2
                                    border.color: Qt.lighter(Theme.primary, 1.2)
                                }
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30
                            radius: 9
                            color: streamDelegate.muted
                                ? Qt.alpha(Theme.outline, 0.16)
                                : Qt.alpha(Theme.primary, 0.12)

                            Text {
                                anchors.centerIn: parent
                                text: streamDelegate.muted ? "󰖁" : "󰕾"
                                color: streamDelegate.muted ? Theme.outline : Theme.primary
                                font.pixelSize: 15
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    if (streamDelegate.node && streamDelegate.node.audio)
                                        streamDelegate.node.audio.muted = !streamDelegate.node.audio.muted
                                }
                                cursorShape: Qt.PointingHandCursor
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 5
                visible: expandedRoot.audioStreams.length === 0

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "♪"
                    color: Theme.outline
                    font.pixelSize: 28
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: Pipewire.ready ? I18n.t("audioMixer.empty") : I18n.t("audioMixer.connecting")
                    color: Theme.outline
                    font.pixelSize: 10
                }
            }
        }
    }
            onCloseRequested: root.close()
        }
    }
    Component {
        id: updaterContent
        Item {
            id: expandedRoot

    signal updateRequested()
    signal closeRequested()

    property real holdProgress: 0
    property bool holdActive: false
    property bool completed: false
    property real wavePhase: 0

    implicitWidth: 340
    implicitHeight: 204

    Rectangle {
        anchors.fill: parent
        radius: 17
        color: Qt.alpha(Theme.surfaceContainer, 0.98)
        border.width: 1
        border.color: Theme.outline
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 9

            Rectangle {
                Layout.preferredWidth: 38
                Layout.preferredHeight: 38
                radius: 12
                color: Qt.alpha(Theme.primary, 0.16)

                Text {
                    anchors.centerIn: parent
                    text: "󰇚"
                    color: Theme.primary
                    font.pixelSize: 20
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: I18n.t("updater.title")
                    color: Theme.surfaceForeground
                    font.pixelSize: 11
                    font.bold: true
                    font.letterSpacing: 0.6
                }

                Text {
                    Layout.fillWidth: true
                    text: UpdateController.localVersion + "  →  " + UpdateController.remoteVersion
                    color: Theme.outline
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }
            }

            Text {
                text: "×"
                color: Theme.outline
                font.pixelSize: 20

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -7
                    onClicked: expandedRoot.closeRequested()
                    cursorShape: Qt.PointingHandCursor
                }
            }
        }

        Text {
            Layout.fillWidth: true
            text: I18n.t("updater.description")
            color: Theme.surfaceForeground
            opacity: 0.78
            font.pixelSize: 10
            wrapMode: Text.WordWrap
        }

        Item { Layout.fillHeight: true }

        Rectangle {
            id: holdButton
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            radius: 12
            color: Qt.darker(Theme.surfaceContainer, 1.28)
            border.width: 1
            border.color: expandedRoot.holdActive ? Theme.primary : Theme.outline
            clip: true

            // The shader draws the fluid and its optional 3D bevel in one pass.
            WaveFill {
                anchors.fill: parent
                z: 0

                radius: parent.radius
                threeDimensional: 1.0
                fillLevel: expandedRoot.holdProgress

                waveAmp: expandedRoot.holdProgress > 0.001
                    && expandedRoot.holdProgress < 0.99
                    ? 40 * Math.sin(expandedRoot.holdProgress * Math.PI)
                    : 0

                phase: expandedRoot.wavePhase

                color1: Qt.darker(Theme.primary, 1.08)
                color2: Theme.primary

                visible: expandedRoot.holdProgress > 0.001
            }

            Text {
                anchors.centerIn: parent
                text: expandedRoot.completed
                    ? I18n.t("updater.installing")
                    : (expandedRoot.holdActive
                        ? I18n.t("updater.holding", { progress: Math.round(expandedRoot.holdProgress * 100) })
                        : I18n.t("updater.hold"))
                color: expandedRoot.holdProgress > 0.48 ? Theme.onPrimary : Theme.surfaceForeground
                font.pixelSize: 11
                font.bold: true
            }

            MouseArea {
                anchors.fill: parent
                enabled: !expandedRoot.completed

                onPressed: {
                    expandedRoot.holdActive = true
                    holdAnimation.restart()
                    SoundController.play("longCharge")
                }

                onReleased: {
                    expandedRoot.holdActive = false
                    SoundController.stop("longCharge")

                    if (!expandedRoot.completed) {
                        holdAnimation.stop()
                        drainAnimation.restart()
                    }
                }

                onCanceled: {
                    expandedRoot.holdActive = false
                    SoundController.stop("longCharge")

                    if (!expandedRoot.completed) {
                        holdAnimation.stop()
                        drainAnimation.restart()
                    }
                }

                cursorShape: Qt.PointingHandCursor
            }
        }

        Text {
            Layout.fillWidth: true
            text: expandedRoot.holdActive
                ? I18n.t("updater.cancelHint")
                : I18n.t("updater.installHint")
            color: Theme.outline
            font.pixelSize: 9
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }

        Text {
            Layout.fillWidth: true

            text: I18n.t("updater.changelog") + " ↗"
            color: Theme.primary
            font.pixelSize: 9
            horizontalAlignment: Text.AlignHCenter

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor

                onClicked: {
                    const parts = String(UpdateController.localVersion)
                        .split(".")
                        .map(Number)

                    parts[parts.length - 1]++

                    const version = parts.join("")

                    Qt.openUrlExternally(
                        "https://github.com/DuckCosmos/wayck/blob/main/CHANGELOG.md#" + version
                    )
                }
            }
        }
    }

    NumberAnimation {
        id: holdAnimation
        target: root
        property: "holdProgress"
        from: 0
        to: 1
        duration: 3904
        easing.type: Easing.Linear

        onFinished: {
            if (!expandedRoot.holdActive || expandedRoot.completed)
                return

            expandedRoot.completed = true
            expandedRoot.updateRequested()
            SoundController.stop("longCharge")
        }
    }

    NumberAnimation {
        id: drainAnimation
        target: root
        property: "holdProgress"
        to: 0
        duration: Math.max(100, expandedRoot.holdProgress * 210)
        easing.type: Easing.OutCubic
    }

    NumberAnimation on wavePhase {
        running: expandedRoot.holdProgress > 0.0
            && expandedRoot.holdProgress < 1.0

        from: 0
        to: Math.PI * 2

        duration: 600
        loops: Animation.Infinite
    }
            onUpdateRequested: { UpdateController.installUpdate(); root.close() }
            onCloseRequested: root.close()
        }
    }

}
