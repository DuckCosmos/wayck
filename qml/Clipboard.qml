import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root

    property bool _winVisible: false
    readonly property string homeDir: Quickshell.env("HOME")
    readonly property string backend: Quickshell.shellPath("wayck-backend")
    property color cPrimary: colorsData.primary || "#ffb59b"
    property color cOnPrimary: colorsData.on_primary || "#55200a"
    property color cSurfaceContainer: colorsData.surface_container_high || "#322824"
    property color cOnSurface: colorsData.on_surface || "#f1dfd9"
    property color cOutline: colorsData.outline || "#a08d86"
    property var colorsData: ({
    })

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

    function open() {
        _winVisible = true;
        hideAnim.stop();
        showAnim.start();
        triggerSearch();
    }

    function close() {
        showAnim.stop();
        hideAnim.start();
    }

    color: "transparent"
    WlrLayershell.namespace: "wayck-clipboard"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: _winVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    implicitWidth: 600
    implicitHeight: 470

    property bool blurEnabled: false
    
    property var blurShape: Region { item: card }
    BackgroundEffect.blurRegion: blurEnabled ? blurShape : null
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
                    // MUDANÇA AQUI
                    root.clipboardList = JSON.parse(text);
                    root.selectedIndex = 0;
                } catch (e) {
                }
            }
        }

    }

    Shortcut {
        sequence: "Escape"
        onActivated: root.close()
    }

    FileView {
        path: root.homeDir + "/.local/state/quickshell/user/generated/colors.json"
        onLoaded: {
            try {
                root.colorsData = JSON.parse(text());
            } catch (e) {
            }
        }
    }

    ParallelAnimation {
        id: showAnim

        SpringAnimation {
            target: content
            property: "y"
            to: 0
            spring: 4
            damping: 0.4
            mass: 0.6
        }

        NumberAnimation {
            target: content
            property: "opacity"
            to: 1
            duration: 200
            easing.type: Easing.OutCubic
        }

    }

    ParallelAnimation {
        id: hideAnim

        onFinished: {
            root._winVisible = false;
            root.dismissed();
        }

        NumberAnimation {
            target: content
            property: "y"
            to: root.height + 50
            duration: 250
            easing.type: Easing.InCubic
        }

    }

    Item {
        id: content

        width: parent.width
        height: parent.height
        y: root.height
        opacity: 0

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: Qt.rgba(root.cSurfaceContainer.r, root.cSurfaceContainer.g, root.cSurfaceContainer.b, root.blurEnabled ? 0.5 : 1.0)
                strokeColor: root.cOutline
                strokeWidth: 1
                joinStyle: ShapePath.RoundJoin
                startX: root.inset + root.topR
                startY: 0

                PathLine {
                    x: root.width - root.inset - root.topR
                    y: 0
                }

                PathArc {
                    x: root.width - root.inset
                    y: root.topR
                    radiusX: root.topR
                    radiusY: root.topR
                }

                PathLine {
                    x: root.width - root.inset
                    y: root.height - root.flare
                }

                PathQuad {
                    x: root.width
                    y: root.height
                    controlX: root.width - root.inset
                    controlY: root.height
                }

                PathLine {
                    x: 0
                    y: root.height
                }

                PathQuad {
                    x: root.inset
                    y: root.height - root.flare
                    controlX: root.inset
                    controlY: root.height
                }

                PathLine {
                    x: root.inset
                    y: root.topR
                }

                PathArc {
                    x: root.inset + root.topR
                    y: 0
                    radiusX: root.topR
                    radiusY: root.topR
                }

            }

        }

        ColumnLayout {
            anchors.fill: parent
            anchors.topMargin: 20
            anchors.bottomMargin: 20
            anchors.leftMargin: root.inset + 20
            anchors.rightMargin: root.inset + 20
            spacing: 15

            Rectangle {
                Layout.fillWidth: true
                height: 42
                color: "transparent"
                border.color: searchInput.activeFocus ? root.cPrimary : "transparent"
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
                    color: root.cOnSurface
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
                        text: "Buscar no clipboard..."
                        color: root.cOnSurface
                        opacity: 0.4
                        font: parent.font
                        visible: !parent.text && !parent.activeFocus
                        anchors.verticalCenter: parent.verticalCenter
                    }

                }

            }

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

                delegate: Rectangle {
                    property bool isSelected: index === root.selectedIndex

                    width: listView.width
                    height: modelData.is_image ? 200 : 48
                    radius: 8
                    clip: true
                    color: isSelected ? root.cPrimary : (mouseArea.containsMouse ? Qt.rgba(root.cOnSurface.r, root.cOnSurface.g, root.cOnSurface.b, 0.08) : "transparent")

                    Process {
                        id: extractImg

                        running: modelData.is_image
                        command: ["sh", "-c", "cliphist decode " + modelData.id + " > /tmp/wayck_clip_" + modelData.id + ".png"]
                    }

                    Item {
                        anchors.fill: parent
                        anchors.margins: 12
                        visible: !modelData.is_image

                        Text {
                            text: modelData.content
                            font.family: Qt.application.font.family
                            font.pixelSize: 14
                            color: isSelected ? root.cOnPrimary : root.cOnSurface
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
                            source: modelData.is_image ? "file:///tmp/wayck_clip_" + modelData.id + ".png" : ""
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            cache: true
                        }

                        Text {
                            Layout.fillWidth: true
                            text: modelData.content.replace("[[ binary data ", "").replace(" ]]", "")
                            font.family: Qt.application.font.family
                            font.pixelSize: 11
                            color: isSelected ? root.cOnPrimary : root.cOnSurface
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
                                root.deleteItem(modelData);
                            }
                        }
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: 80
                        }

                    }

                }

            }

        }

    }

}
