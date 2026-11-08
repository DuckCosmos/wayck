import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../"

PanelWindow {
    id: root

    property bool _winVisible: false
    property bool closing: false
    property real revealProgress: 0

    readonly property string homeDir: Quickshell.env("HOME")
    readonly property string backend: Quickshell.shellPath("wayck-backend")

    property var clipboardList: []
    property int selectedIndex: 0
    property int inset: 60
    property int topR: 15
    property int flare: 90

    signal dismissed()

    function triggerSearch() {
        clipboardBackend.running = true;
    }

    function copyItem(item) {
        Quickshell.execDetached([root.backend, "--clipboard-copy", item.id]);
        root.close();
    }

    function deleteItem(item) {
        let newList = [];
        for (let i = 0; i < root.clipboardList.length; i++) {
            if (root.clipboardList[i].id !== item.id) {
                newList.push(root.clipboardList[i]);
            }
        }
        root.clipboardList = newList;

        if (root.selectedIndex >= root.clipboardList.length) {
            root.selectedIndex = Math.max(0, root.clipboardList.length - 1);
        }

        Quickshell.execDetached([root.backend, "--clipboard-delete", item.id]);
    }

    function clearClipboard() {
        Quickshell.execDetached([root.backend, "--clipboard-clear"]);
        root.close()
    }

    function open() {
        _winVisible = true
        closing = false
        revealProgress = 1
        triggerSearch()
    }

    function close() {
        if (!_winVisible || closing)
            return

        closing = true
        revealProgress = 0
    }

    onRevealProgressChanged: {
        if (closing && revealProgress <= 0.001) {
            _winVisible = false
            closing = false
            dismissed()
        }
    }

    color: "transparent"
    WlrLayershell.namespace: "wayck-clipboard"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: _winVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    implicitWidth: 800
    implicitHeight: 520
    visible: _winVisible

    Component.onCompleted: root.open()

    anchors {
        bottom: true
    }

    Process {
        id: clipboardBackend
        command: [root.backend, "--clipboard-list", searchInput.text]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.clipboardList = JSON.parse(text);
                    root.selectedIndex = 0;
                } catch (e) {}
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        onActivated: root.close()
    }

    Behavior on revealProgress {
        NumberAnimation {
            duration: root.closing
                ? Motion.surfaceCloseDuration
                : Motion.surfaceOpenDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.closing
                ? Motion.surfaceCloseCurve
                : Motion.surfaceOpenCurve
        }
    }

    Item {
        id: content
        width: parent.width
        height: root.height * root.revealProgress
        y: root.height * (1 - root.revealProgress)
        opacity: root.revealProgress
        clip: true

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: Qt.darker(Theme.onSurface, 10)
                strokeColor: Theme.outline
                strokeWidth: 1
                joinStyle: ShapePath.RoundJoin
                startX: root.inset + root.topR
                startY: 0

                PathLine { x: root.width - root.inset - root.topR; y: 0 }
                PathArc {
                    x: root.width - root.inset
                    y: root.topR
                    radiusX: root.topR
                    radiusY: root.topR
                }
                PathLine { x: root.width - root.inset; y: content.height - root.flare }
                PathQuad {
                    x: root.width
                    y: content.height
                    controlX: root.width - root.inset
                    controlY: content.height
                }
                PathLine { x: 0; y: content.height }
                PathQuad {
                    x: root.inset
                    y: content.height - root.flare
                    controlX: root.inset
                    controlY: content.height
                }
                PathLine { x: root.inset; y: root.topR }
                PathArc {
                    x: root.inset + root.topR
                    y: 0
                    radiusX: root.topR
                    radiusY: root.topR
                }
            }
        }

        // Idiomas RTL (árabe, persa): espelha o layout da janela.
        LayoutMirroring.enabled: I18n.rtl
        LayoutMirroring.childrenInherit: true

        ColumnLayout {
            anchors.fill: parent
            anchors.topMargin: 20
            anchors.bottomMargin: 20
            anchors.leftMargin: root.inset + 20
            anchors.rightMargin: root.inset + 20
            spacing: 15

            Timer {
                id: searchDebounceTimer
                interval: 50
                repeat: false
                onTriggered: root.triggerSearch()
            }

            ListView {
                id: listView
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: root.clipboardList
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
                    id: delegateItem
                    property bool isSelected: index === root.selectedIndex
                    property bool imgReady: false

                    property bool deleting: false

                    NumberAnimation {
                        id: fadeOut
                        target: delegateItem
                        property: "opacity"
                        to: 0
                        duration: 260
                        easing.type: Easing.InOutCubic

                        onFinished: {
                            root.deleteItem(modelData)
                        }
                    }

                    width: listView.width
                    height: modelData.is_image ? 200 : 48
                    radius: 8
                    clip: true

                    Behavior on height {
                        NumberAnimation {
                            duration: Motion.layoutDuration
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Motion.layoutCurve
                        }
                    }
                    Behavior on color {
                        ColorAnimation {
                            duration: Motion.colorDuration
                            easing.type: Motion.standard
                        }
                    }
                    color: isSelected ? Theme.primary : (mouseArea.containsMouse ? Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.08) : Qt.darker(Theme.surfaceContainer, 1.8))

                    Process {
                        id: extractImg
                        running: modelData.is_image && !imgReady
                        command: ["sh", "-c", "cliphist decode " + modelData.id + " > /tmp/wayck_clip_" + modelData.id + ".png"]
                        onExited: imgReady = true
                    }

                    Item {
                        anchors.fill: parent
                        anchors.margins: 12
                        visible: !modelData.is_image

                        Text {
                            text: modelData.content
                            textFormat: Text.PlainText
                            font.family: Qt.application.font.family
                            font.pixelSize: 14
                            color: isSelected ? Theme.onPrimary : Theme.onSurface
                            width: parent.width
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 4
                        visible: modelData.is_image

                        Image {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            source: (modelData.is_image && imgReady) ? "file:///tmp/wayck_clip_" + modelData.id + ".png" : ""
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            cache: true
                        }

                        Text {
                            Layout.fillWidth: true
                            text: modelData.content.replace("[[ binary data ", "").replace(" ]]", "")
                            textFormat: Text.PlainText
                            font.family: Qt.application.font.family
                            font.pixelSize: 11
                            color: isSelected ? Theme.onPrimary : Theme.onSurface
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            opacity: 0.8
                        }
                    }

                    MouseArea {
                        id: mouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton

                        onClicked: (mouse) => {
                            root.selectedIndex = index;
                            if (mouse.button === Qt.LeftButton) {
                                root.copyItem(modelData);
                            } else if (mouse.button === Qt.RightButton) {
                                deleting = true;
                                fadeOut.start();
                            }
                        }
                    }
                }
            }

            RowLayout {
                Rectangle {
                    Layout.fillWidth: true
                    height: 42
                    color: Qt.darker(Theme.surfaceContainer, 1.8)
                    border.color: searchInput.activeFocus ? Theme.primary : "transparent"
                    border.width: 1
                    radius: 5
                    clip: true

                    TextInput {
                        id: searchInput
                        anchors.fill: parent
                        anchors.margins: 10
                        verticalAlignment: TextInput.AlignVCenter
                        font.family: Qt.application.font.family
                        font.pixelSize: 16
                        color: Theme.onSurface
                        focus: true
                        onTextChanged: searchDebounceTimer.restart()
                        
                        Keys.onPressed: (event) => {
                            if (event.key === Qt.Key_Down) {
                                if (root.clipboardList.length > 0)
                                    root.selectedIndex = Math.min(root.selectedIndex + 1, root.clipboardList.length - 1);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Up) {
                                if (root.selectedIndex > 0)
                                    root.selectedIndex--;
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                if (root.clipboardList.length > root.selectedIndex)
                                    root.copyItem(root.clipboardList[root.selectedIndex]);
                                event.accepted = true;
                            }
                        }

                        Text {
                            text: I18n.t("clipboard.search")
                            color: Theme.onSurface
                            opacity: 0.4
                            font: parent.font
                            width: parent.width
                            horizontalAlignment: I18n.horizontalAlignment
                            elide: Text.ElideRight
                            visible: !parent.text && !parent.activeFocus
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                Rectangle {
                    Layout.preferredHeight: 42
                    Layout.preferredWidth: Math.max(122, clearLabel.implicitWidth + 36)
                    color: mouseClear.containsMouse ? Theme.primary : Qt.darker(Theme.surfaceContainer, 1.8)
                    border.color: Theme.primary
                    border.width: 1
                    radius: 5
                    
                    Text {
                        id: clearLabel
                        anchors.centerIn: parent
                        text: "メ " + I18n.t("clipboard.clear")
                        color: mouseClear.containsMouse ? Qt.darker(Theme.surfaceContainer, 1.8) : Theme.onSurface
                        font.pixelSize: 18
                    }

                    MouseArea {
                        id: mouseClear
                        anchors.fill: parent
                        hoverEnabled: true

                        onClicked: {
                            root.clearClipboard();
                        }
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: 130
                            easing.type: Easing.InOutCubic
                        }
                    }
                }
            }
        }
    }
}