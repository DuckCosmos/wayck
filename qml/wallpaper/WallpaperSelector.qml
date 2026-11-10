
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick.Controls
import "../"

PanelWindow {
    id: root

    property bool opened: false
    property bool initializing: false
    property bool applying: false

    property bool listReady: false
    property bool currentReady: false

    property var wallpapers: []
    property var filteredWallpapers: []

    property string originalWallpaper: ""
    property string previewedWallpaper: ""
    property string applyingPath: ""
    property string pendingPreviewPath: ""
    property string activePreviewPath: ""

    readonly property var blurShape: Region { item: selector }

    onOpenedChanged: {
        if (opened)
            closeTimer.stop()
        else
            closeTimer.restart()
    }

    readonly property string wallpaperCommand: {
        const configured = Quickshell.env("WAYCK_WALLPAPER")
        return configured && configured.length > 0
            ? configured
            : "wayck-wallpaper"
    }

    readonly property string selectedWallpaper:
        carousel.currentIndex >= 0 &&
        carousel.currentIndex < filteredWallpapers.length
            ? filteredWallpapers[carousel.currentIndex]
            : ""

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    visible: opened || closeTimer.running
    focusable: opened
    aboveWindows: true
    exclusiveZone: -1

    color: "transparent"
    WlrLayershell.namespace: "wayck-wallpaper-selector"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    BackgroundEffect.blurRegion: Config.blur ? blurShape : null

    function openSelector(): void {
        if (opened)
            return

        opened = true
        initializing = true
        applying = false
        pendingPreviewPath = ""
        activePreviewPath = ""

        wallpapers = []
        filteredWallpapers = []

        originalWallpaper = ""
        previewedWallpaper = ""

        listReady = false
        currentReady = false

        searchInput.text = ""
        filterTimer.stop()
        previewTimer.stop()

        listProcess.exec([wallpaperCommand, "list"])
        currentProcess.exec([wallpaperCommand, "current"])
    }

    function finishLoading(): void {
        if (!listReady || !currentReady)
            return

        const index = filteredWallpapers.indexOf(originalWallpaper)

        Qt.callLater(() => {
            if (!opened)
                return

            carousel.currentIndex = index >= 0
                ? index
                : (filteredWallpapers.length > 0 ? 0 : -1)

            previewedWallpaper = originalWallpaper
            initializing = false

            carousel.forceActiveFocus()
        })
    }

    function updateFilter(): void {
        if (!listReady)
            return

        const previous = selectedWallpaper ||
            previewedWallpaper ||
            originalWallpaper

        const query = searchInput.text.trim().toLowerCase()

        const results = query.length === 0
            ? wallpapers.slice()
            : wallpapers.filter(path => {
                const filename = path.substring(
                    path.lastIndexOf("/") + 1
                ).toLowerCase()

                return filename.includes(query)
            })

        let nextIndex = previous
            ? results.indexOf(previous)
            : -1

        if (nextIndex < 0)
            nextIndex = results.length > 0 ? 0 : -1

        initializing = true
        filteredWallpapers = results

        Qt.callLater(() => {
            if (!opened)
                return

            carousel.currentIndex = nextIndex
            initializing = false

            if (selectedWallpaper &&
                selectedWallpaper !== previewedWallpaper) {
                previewSelected()
            }
        })
    }

    function previewSelected(): void {
        const path = selectedWallpaper

        if (!path)
            return

        if (path === previewedWallpaper
                && (!previewProcess.running || activePreviewPath === path)
                && pendingPreviewPath === "") {
            return
        }

        pendingPreviewPath = path
        previewTimer.restart()
    }

    function runPreview(): void {
        if (previewProcess.running || !pendingPreviewPath)
            return

        const path = pendingPreviewPath
        pendingPreviewPath = ""

        if (path === previewedWallpaper)
            return

        activePreviewPath = path
        previewProcess.exec([wallpaperCommand, "set", path])
    }

    function confirmSelector(): void {
        if (applying)
            return

        const path = selectedWallpaper
        if (!path) {
            cancelSelector()
            return
        }

        // Selection changes already preview through wayck-wallpaper (including
        // Matugen). Enter commits the highlighted item and closes the selector.
        previewTimer.stop()

        if (path !== previewedWallpaper && path !== activePreviewPath) {
            pendingPreviewPath = path
            if (!previewProcess.running)
                runPreview()
        } else if (pendingPreviewPath !== path) {
            pendingPreviewPath = ""
        }

        originalWallpaper = path
        opened = false
    }

    function cancelSelector(): void {
        if (applying)
            return

        previewTimer.stop()

        if (originalWallpaper
                && (previewedWallpaper !== originalWallpaper
                    || (previewProcess.running && activePreviewPath !== originalWallpaper))) {
            pendingPreviewPath = originalWallpaper
            if (!previewProcess.running)
                runPreview()
        } else {
            pendingPreviewPath = ""
        }

        opened = false
    }

    FocusScope {
        id: focusRoot

        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: event => {
            root.cancelSelector()
            event.accepted = true
        }

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.22)
            opacity: root.opened ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: Motion.contentFadeDuration
                    easing.type: Motion.standard
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            z: 0
            enabled: root.opened
            onClicked: root.cancelSelector()
        }

        Rectangle {
            id: selector
            anchors.centerIn: parent
            width: root.opened
                ? Math.max(300, Math.min(620, focusRoot.width - 32))
                : 174
            height: root.opened
                ? Math.max(220, Math.min(270, focusRoot.height - 32))
                : 48
            radius: root.opened ? 16 : 24
            color: Qt.alpha(Theme.surfaceContainer, Config.blur ? 0.66 : 0.96)
            border.width: 1
            border.color: Theme.outline
            z: 1

            Behavior on width {
                NumberAnimation {
                    duration: root.opened ? Motion.surfaceOpenDuration : Motion.surfaceCloseDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: root.opened ? Motion.surfaceOpenCurve : Motion.surfaceCloseCurve
                }
            }

            Behavior on height {
                NumberAnimation {
                    duration: root.opened ? Motion.surfaceOpenDuration : Motion.surfaceCloseDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: root.opened ? Motion.surfaceOpenCurve : Motion.surfaceCloseCurve
                }
            }

            Behavior on radius {
                NumberAnimation {
                    duration: root.opened ? Motion.surfaceOpenDuration : Motion.surfaceCloseDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: root.opened ? Motion.surfaceOpenCurve : Motion.surfaceCloseCurve
                }
            }

            ColumnLayout {
                anchors.fill: parent

                anchors.leftMargin: 18
                anchors.rightMargin: 18
                anchors.topMargin: 14
                anchors.bottomMargin: 14

                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 22

                    Text {
                        text: I18n.t("wallpaperSelector.title")
                        color: Theme.surfaceForeground
                        font.pixelSize: 11
                        font.bold: true
                        font.letterSpacing: 1.2
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: carousel.count > 0
                            ? (Math.max(0, carousel.currentIndex + 1) + " / " + carousel.count)
                            : "0 / 0"
                        color: Theme.outline
                        font.pixelSize: 11
                    }
                }

                PathView {
                    id: carousel

                    Layout.fillWidth: true
                    Layout.preferredHeight: 126

                    clip: true

                    focus: true
                    interactive: true

                    model: root.filteredWallpapers

                    pathItemCount: 3
                    cacheItemCount: 3

                    preferredHighlightBegin: 0.5
                    preferredHighlightEnd: 0.5

                    highlightRangeMode: PathView.StrictlyEnforceRange
                    snapMode: PathView.SnapOneItem

                    highlightMoveDuration: Motion.wallpaperMoveDuration
                    flickDeceleration: 1800
                    dragMargin: height / 2

                    movementDirection: PathView.Shortest

                    onCurrentIndexChanged: {
                        if (root.initializing || !root.opened)
                            return

                        previewSelected()
                    }

                    Keys.onLeftPressed: event => {
                        decrementCurrentIndex()
                        event.accepted = true
                    }

                    Keys.onRightPressed: event => {
                        incrementCurrentIndex()
                        event.accepted = true
                    }

                    Keys.onReturnPressed: event => {
                        root.confirmSelector()
                        event.accepted = true
                    }

                    Keys.onEnterPressed: event => {
                        root.confirmSelector()
                        event.accepted = true
                    }

                    Keys.onEscapePressed: event => {
                        root.cancelSelector()
                        event.accepted = true
                    }

                    path: Path {
                        startX: 82
                        startY: carousel.height / 2

                        PathAttribute { name: "itemScale"; value: 0.76 }
                        PathAttribute { name: "itemOpacity"; value: 0.42 }

                        PathLine {
                            x: carousel.width / 2
                            y: carousel.height / 2
                        }

                        PathAttribute { name: "itemScale"; value: 1.04 }
                        PathAttribute { name: "itemOpacity"; value: 1.0 }

                        PathLine {
                            x: carousel.width - 82
                            y: carousel.height / 2
                        }

                        PathAttribute { name: "itemScale"; value: 0.76 }
                        PathAttribute { name: "itemOpacity"; value: 0.42 }
                    }

                    delegate: Item {
                        id: wallpaperItem

                        required property string modelData
                        required property int index

                        width: 156
                        height: 108

                        scale: PathView.itemScale
                        opacity: PathView.itemOpacity

                        visible: PathView.onPath

                        z: PathView.isCurrentItem ? 1 : 0

                        Rectangle {
                            anchors.fill: parent
                            radius: 11
                            color: Theme.surfaceContainer
                            clip: true

                            Image {
                                anchors.fill: parent
                                source: "file://" + wallpaperItem.modelData
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: true
                                smooth: true
                            }

                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: 28
                                color: Qt.rgba(0, 0, 0, 0.48)
                            }

                            Text {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                anchors.bottomMargin: 7
                                text: wallpaperItem.modelData.substring(
                                    wallpaperItem.modelData.lastIndexOf("/") + 1
                                )
                                color: "white"
                                font.pixelSize: 9
                                elide: Text.ElideMiddle
                            }
                        }

                        TapHandler {
                            onTapped: {
                                if (carousel.currentIndex === wallpaperItem.index) {
                                    root.previewSelected()
                                } else {
                                    carousel.currentIndex = wallpaperItem.index
                                }
                            }
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true

                    visible: root.listReady &&
                        carousel.count === 0

                    text: root.wallpapers.length === 0
                        ? I18n.t("wallpaperSelector.empty")
                        : I18n.t("wallpaperSelector.noResults")

                    color: Theme.surfaceForeground
                    font.pixelSize: 13
                    horizontalAlignment: Text.AlignHCenter
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36

                    color: Qt.alpha(Theme.surfaceContainer, 0.7)
                    radius: 9

                    TextField {
                        background: Item {}
                        id: searchInput

                        anchors.fill: parent

                        anchors.leftMargin: 14
                        anchors.rightMargin: 14

                        verticalAlignment: TextInput.AlignVCenter

                        font.pixelSize: 14

                        color: Theme.surfaceForeground
                        placeholderText: I18n.t("launcher.search")
                        placeholderTextColor: Qt.lighter(
                            Theme.surfaceContainer,
                            1.8
                        )

                        selectionColor: Theme.primary
                        selectedTextColor: Theme.surfaceForeground

                        selectByMouse: true
                        activeFocusOnPress: true

                        onTextChanged: filterTimer.restart()

                        onAccepted: root.confirmSelector()

                        Keys.onEscapePressed: event => {
                            root.cancelSelector()
                            event.accepted = true
                        }
                    }
                }
            }
        }
    }

    Timer {
        id: closeTimer
        interval: Motion.surfaceCloseDuration
        repeat: false
    }

    Timer {
        id: previewTimer

        interval: 75
        repeat: false

        onTriggered: root.runPreview()
    }

    Timer {
        id: filterTimer

        interval: 120
        repeat: false

        onTriggered: root.updateFilter()
    }

    Process {
        id: listProcess

        stdout: StdioCollector {
            id: listOutput

            onStreamFinished: {
                const output = listOutput.text.trim()

                root.wallpapers = output.length > 0
                    ? output.split(/\r?\n/)
                    : []

                root.filteredWallpapers = root.wallpapers.slice()
                root.listReady = true

                root.finishLoading()
            }
        }

        stderr: StdioCollector {
            id: listErrors
        }
    }

    Process {
        id: currentProcess

        stdout: StdioCollector {
            id: currentOutput

            onStreamFinished: {
                root.originalWallpaper = currentOutput.text.trim()
                root.currentReady = true

                root.finishLoading()
            }
        }

        stderr: StdioCollector {
            id: currentErrors
        }
    }

    Process {
        id: previewProcess

        property string activePath: ""

        stderr: StdioCollector {
            id: previewErrors
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root.previewedWallpaper = activePath
            } else {
                console.warn(
                    "[WallpaperSelector] falha ao pré-visualizar/aplicar Matugen:",
                    previewErrors.text.trim()
                )
            }

            if (root.pendingPreviewPath && root.pendingPreviewPath !== activePath)
                root.runPreview()
            else if (root.pendingPreviewPath === activePath)
                root.pendingPreviewPath = ""
        }
    }

    IpcHandler {
        target: "wallpaper"

        function open(): void {
            root.openSelector()
        }

        function close(): void {
            root.cancelSelector()
        }
    }
}
