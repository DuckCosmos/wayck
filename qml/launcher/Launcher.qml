
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../"

PanelWindow {
    id: root

    signal dismissed()

    property bool blurEnabled: false
    property bool shown: false
    property bool closing: false

    property real inset: 90
    property real topR: 15
    property real flare: 90

    readonly property real surfaceInset:
        Math.min(root.inset, card.width * 0.18)

    readonly property real surfaceTopR:
        Math.min(root.topR, card.width * 0.08, card.height * 0.2)

    readonly property real surfaceFlare:
        Math.min(root.flare, card.height * 0.35)

    readonly property string homeDir: Quickshell.env("HOME")
    readonly property string backend: Quickshell.shellPath("wayck-backend")

    property var appList: []
    property int selectedIndex: 0
    property bool searchPending: false

    WlrLayershell.namespace: "wayck-launcher"
    WlrLayershell.layer: WlrLayer.Overlay

    WlrLayershell.keyboardFocus: closing
        ? WlrKeyboardFocus.None
        : WlrKeyboardFocus.Exclusive

    WlrLayershell.exclusiveZone: -1

    property var blurShape: Region {
        item: card
    }

    BackgroundEffect.blurRegion: blurEnabled
        ? blurShape
        : null

    anchors {
        bottom: true
    }

    margins {
        bottom: 0
    }

    implicitWidth: 700
    implicitHeight: 450
    color: "transparent"

    function triggerSearch() {
        if (rustBackend.running) {
            searchPending = true
            return
        }

        rustBackend.running = true
    }

    function launchApp(item) {
        if (!item)
            return

        Quickshell.execDetached([
            root.backend,
            "--exec",
            item.nome,
            item.exec
        ])

        close()
    }

    function close() {
        if (!shown || closing)
            return

        searchInput.focus = false
        closing = true
        shown = false

        closeTimer.start()
    }

    Process {
        id: rustBackend

        command: [
            root.backend,
            "--filter",
            searchInput.text
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.appList = JSON.parse(text)
                    root.selectedIndex = 0
                } catch (e) {
                    console.warn(
                        "[WAYCK LAUNCHER] Falha ao interpretar os aplicativos:",
                        e
                    )
                }
            }
        }

        onRunningChanged: {
            if (!running && root.searchPending) {
                root.searchPending = false
                root.triggerSearch()
            }
        }
    }

    Timer {
        id: closeTimer

        interval: Motion.surfaceCloseDuration + 40
        repeat: false

        onTriggered: root.dismissed()
    }

    Timer {
        id: searchDebounceTimer

        interval: 20
        repeat: false

        onTriggered: root.triggerSearch()
    }

    Rectangle {
        id: card

        property real progress: root.shown ? 1 : 0

        readonly property real collapsedWidth:
            Math.min(190, parent.width * 0.55)

        readonly property real collapsedHeight: 54

        readonly property real expandedWidth: parent.width
        readonly property real expandedHeight: parent.height

        readonly property real collapsedX:
            (parent.width - collapsedWidth) / 2

        readonly property real collapsedY:
            parent.height - collapsedHeight

        readonly property real expandedX: 0
        readonly property real expandedY: 0

        readonly property real contentProgress:
            Math.max(0, Math.min(1, (progress - 0.18) / 0.82))

        x: collapsedX + (expandedX - collapsedX) * progress
        y: collapsedY + (expandedY - collapsedY) * progress

        width: collapsedWidth
            + (expandedWidth - collapsedWidth) * progress

        height: collapsedHeight
            + (expandedHeight - collapsedHeight) * progress

        clip: true
        antialiasing: true

        color: "transparent"
        border.width: 0

        Behavior on progress {
            NumberAnimation {
                duration: root.shown
                    ? Motion.surfaceOpenDuration
                    : Motion.surfaceCloseDuration

                easing.type: Easing.BezierSpline

                easing.bezierCurve: root.shown
                    ? Motion.surfaceOpenCurve
                    : Motion.surfaceCloseCurve
            }
        }

        Shape {
            id: surfaceShape

            anchors.fill: parent
            z: 0

            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: Qt.rgba(
                    Theme.surfaceContainer.r,
                    Theme.surfaceContainer.g,
                    Theme.surfaceContainer.b,
                    root.blurEnabled ? 0.5 : 1.0
                )

                strokeColor: Theme.outline
                strokeWidth: 1
                joinStyle: ShapePath.RoundJoin

                startX: root.surfaceInset + root.surfaceTopR
                startY: 0

                PathLine {
                    x: card.width
                        - root.surfaceInset
                        - root.surfaceTopR

                    y: 0
                }

                PathArc {
                    x: card.width - root.surfaceInset
                    y: root.surfaceTopR

                    radiusX: root.surfaceTopR
                    radiusY: root.surfaceTopR
                }

                PathLine {
                    x: card.width - root.surfaceInset
                    y: card.height - root.surfaceFlare
                }

                PathQuad {
                    x: card.width
                    y: card.height

                    controlX: card.width - root.surfaceInset
                    controlY: card.height
                }

                PathLine {
                    x: 0
                    y: card.height
                }

                PathQuad {
                    x: root.surfaceInset
                    y: card.height - root.surfaceFlare

                    controlX: root.surfaceInset
                    controlY: card.height
                }

                PathLine {
                    x: root.surfaceInset
                    y: root.surfaceTopR
                }

                PathArc {
                    x: root.surfaceInset + root.surfaceTopR
                    y: 0

                    radiusX: root.surfaceTopR
                    radiusY: root.surfaceTopR
                }
            }
        }

        Item {
            id: content

            anchors.fill: parent
            z: 1

            opacity: card.contentProgress
            enabled: card.progress > 0.98
            visible: card.progress > 0.01

            Behavior on opacity {
                NumberAnimation {
                    duration: Motion.contentFadeDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Motion.contentCurve
                }
            }

            LayoutMirroring.enabled: I18n.rtl
            LayoutMirroring.childrenInherit: true

            ColumnLayout {
                anchors.fill: parent

                anchors.topMargin: 20
                anchors.bottomMargin: 20

                anchors.leftMargin: root.surfaceInset + 20
                anchors.rightMargin: root.surfaceInset + 20

                spacing: 10

                Rectangle {
                    Layout.fillWidth: true
                    height: 1

                    color: Theme.outline
                    opacity: 0.1
                }

                ListView {
                    id: listView

                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    clip: true

                    model: root.appList
                    currentIndex: root.selectedIndex

                    spacing: 4

                    add: Transition {
                        NumberAnimation {
                            property: "opacity"

                            from: 0
                            to: 1

                            duration: Motion.contentFadeDuration
                            easing.type: Motion.standard
                        }
                    }

                    displaced: Transition {
                        NumberAnimation {
                            properties: "x,y"

                            duration: Motion.layoutDuration

                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Motion.layoutCurve
                        }
                    }

                    delegate: Rectangle {
                        width: listView.width
                        height: 40

                        radius: 8

                        property bool isSelected:
                            index === root.selectedIndex

                        color: isSelected
                            ? Theme.primary
                            : (
                                mouseArea.containsMouse
                                ? Qt.rgba(
                                    Theme.surfaceForeground.r,
                                    Theme.surfaceForeground.g,
                                    Theme.surfaceForeground.b,
                                    0.08
                                )
                                : "transparent"
                            )

                        Behavior on color {
                            ColorAnimation {
                                duration: Motion.colorDuration
                                easing.type: Motion.standard
                            }
                        }

                        RowLayout {
                            anchors.fill: parent

                            anchors.leftMargin: 8
                            anchors.rightMargin: 8

                            spacing: 10

                            Image {
                                source: modelData.icone_path
                                    ? "file://" + modelData.icone_path
                                    : ""

                                Layout.preferredWidth: 24
                                Layout.preferredHeight: 24

                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                            }

                            Text {
                                text: modelData.nome

                                font.family: Qt.application.font.family
                                font.pixelSize: 15

                                color: isSelected
                                    ? Theme.onPrimary
                                    : Theme.surfaceForeground

                                Layout.fillWidth: true

                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            id: mouseArea

                            anchors.fill: parent
                            hoverEnabled: true

                            onClicked: {
                                root.selectedIndex = index
                                SoundController.play("clickbutton")
                                root.launchApp(modelData)
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 42

                    color: "transparent"

                    border.color: searchInput.activeFocus
                        ? Theme.primary
                        : "transparent"

                    border.width: 1
                    radius: 8

                    TextInput {
                        id: searchInput

                        anchors.fill: parent
                        anchors.margins: 10

                        verticalAlignment: TextInput.AlignVCenter

                        font.family: Qt.application.font.family
                        font.pixelSize: 16

                        color: Theme.surfaceForeground

                        Text {
                            text: I18n.t("launcher.search")

                            color: Theme.surfaceForeground
                            opacity: 0.4

                            font: parent.font
                            width: parent.width

                            horizontalAlignment: I18n.horizontalAlignment
                            elide: Text.ElideRight

                            visible: !parent.text && !parent.activeFocus

                            anchors.verticalCenter: parent.verticalCenter
                        }

                        onTextChanged: searchDebounceTimer.restart()

                        Keys.onPressed: event => {
                            if (!event.isAutoRepeat)
                                SoundController.play("click")

                            if (event.key === Qt.Key_Escape) {
                                root.close()

                            } else if (event.key === Qt.Key_Down) {
                                if (root.appList.length > 0) {
                                    root.selectedIndex = Math.min(
                                        root.selectedIndex + 1,
                                        root.appList.length - 1
                                    )
                                }

                                event.accepted = true

                            } else if (event.key === Qt.Key_Up) {
                                if (root.selectedIndex > 0)
                                    root.selectedIndex--

                                event.accepted = true

                            } else if (
                                event.key === Qt.Key_Return ||
                                event.key === Qt.Key_Enter
                            ) {
                                if (root.appList.length > root.selectedIndex)
                                    SoundController.play("clickbutton")
                                    root.launchApp(
                                        root.appList[root.selectedIndex]
                                    )

                                event.accepted = true
                            }
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        triggerSearch()

        Qt.callLater(() => {
            root.shown = true
            searchInput.forceActiveFocus()
        })
    }
}
