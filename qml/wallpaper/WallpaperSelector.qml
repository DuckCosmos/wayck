
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
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

    function openSelector(): void {
        if (opened)
            return

        opened = true
        initializing = true
        applying = false

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
                previewTimer.restart()
            }
        })
    }

    function previewSelected(): void {
        const path = selectedWallpaper

        if (!path || path === previewedWallpaper)
            return

        previewedWallpaper = path

        previewProcess.exec([
            "hyprctl",
            "hyprpaper",
            "wallpaper",
            "," + path + ",cover"
        ])
    }

    function confirmSelector(): void {
        if (applying)
            return

        const path = selectedWallpaper

        if (!path) {
            opened = false
            return
        }

        applying = true
        applyingPath = path

        applyProcess.exec([
            wallpaperCommand,
            "set",
            path
        ])
    }

    function cancelSelector(): void {
        if (applying)
            return

        previewTimer.stop()

        if (originalWallpaper &&
            previewedWallpaper !== originalWallpaper) {
            previewedWallpaper = originalWallpaper

            previewProcess.exec([
                "hyprctl",
                "hyprpaper",
                "wallpaper",
                "," + originalWallpaper + ",cover"
            ])
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
            color: "#99000000"
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

        MorphSurface {
            id: selector
            anchors.centerIn: parent
            expanded: root.opened
            expandedWidth: Math.max(240, Math.min(1120, focusRoot.width - 40))
            expandedHeight: Math.max(180, Math.min(380, focusRoot.height - 40))
            collapsedWidth: 168
            collapsedHeight: 54
            expandedRadius: 18
            collapsedRadius: 27
            color: Qt.darker(Theme.surfaceContainer, 1.5)
            z: 1

            ColumnLayout {
                anchors.fill: parent

                anchors.leftMargin: 28
                anchors.rightMargin: 28
                anchors.topMargin: 28
                anchors.bottomMargin: 28

                spacing: 18

                PathView {
                    id: carousel

                    Layout.fillWidth: true
                    Layout.preferredHeight: 250

                    clip: true

                    focus: true
                    interactive: true

                    model: root.filteredWallpapers

                    pathItemCount: 5
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

                        previewTimer.restart()
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
                        startX: 100
                        startY: carousel.height / 2

                        PathAttribute {
                            name: "itemScale"
                            value: 0.68
                        }

                        PathAttribute {
                            name: "itemOpacity"
                            value: 0.35
                        }

                        PathLine {
                            x: carousel.width / 2
                            y: carousel.height / 2
                        }

                        PathAttribute {
                            name: "itemScale"
                            value: 1.12
                        }

                        PathAttribute {
                            name: "itemOpacity"
                            value: 1.0
                        }

                        PathLine {
                            x: carousel.width - 100
                            y: carousel.height / 2
                        }

                        PathAttribute {
                            name: "itemScale"
                            value: 0.68
                        }

                        PathAttribute {
                            name: "itemOpacity"
                            value: 0.35
                        }
                    }

                    delegate: Item {
                        id: wallpaperItem

                        required property string modelData
                        required property int index

                        width: 180
                        height: 210

                        scale: PathView.itemScale
                        opacity: PathView.itemOpacity

                        visible: PathView.onPath

                        z: PathView.isCurrentItem ? 1 : 0

                        Image {
                            anchors.fill: parent

                            source: "file://" + wallpaperItem.modelData

                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            smooth: true
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
                        ? "Nenhum wallpaper encontrado"
                        : "Nenhum resultado encontrado"

                    color: Theme.onSurface
                    font.pixelSize: 13
                    horizontalAlignment: Text.AlignHCenter
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 46

                    color: Qt.darker(Theme.surfaceContainer, 1.3)
                    radius: 0

                    TextField {
                        background: Item {}
                        id: searchInput

                        anchors.fill: parent

                        anchors.leftMargin: 14
                        anchors.rightMargin: 14

                        verticalAlignment: TextInput.AlignVCenter

                        font.pixelSize: 14

                        color: Theme.onSurface
                        placeholderText: "Pesquisar wallpaper..."
                        placeholderTextColor: Qt.lighter(
                            Theme.surfaceContainer,
                            1.8
                        )

                        selectionColor: Theme.primary
                        selectedTextColor: Theme.onSurface

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

        interval: 100
        repeat: false

        onTriggered: root.previewSelected()
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

        stderr: StdioCollector {
            id: previewErrors
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                console.warn(
                    "[WallpaperSelector] falha na prévia:",
                    previewErrors.text.trim()
                )
            }
        }
    }

    Process {
        id: applyProcess

        stderr: StdioCollector {
            id: applyErrors
        }

        onExited: (exitCode, exitStatus) => {
            root.applying = false

            if (exitCode === 0) {
                root.originalWallpaper = root.applyingPath
                root.previewedWallpaper = root.applyingPath
                root.opened = false

                console.log(
                    "[WallpaperSelector] aplicado:",
                    root.applyingPath
                )
            } else {
                console.warn(
                    "[WallpaperSelector] falha ao aplicar:",
                    applyErrors.text.trim()
                )
            }
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
