import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root

    signal dismissed()

    property bool blurEnabled: false

    property bool shown: false
    
    property bool closing: false

    WlrLayershell.namespace: "wayck-launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: closing ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive
    WlrLayershell.exclusiveZone: -1

    property var blurShape: Region { item: card }
    BackgroundEffect.blurRegion: blurEnabled ? blurShape : null

    anchors { top: true }
    margins { top: 150 }

    implicitWidth: 450
    implicitHeight: 500
    color: "transparent"

    readonly property string homeDir: Quickshell.env("HOME")
    readonly property string backend: Quickshell.shellPath("wayck-backend")

    property color cPrimary: colorsData.primary || "#ffb59b"
    property color cOnPrimary: colorsData.on_primary || "#55200a"
    property color cSurfaceContainer: colorsData.surface_container_high || "#322824"
    property color cOnSurface: colorsData.on_surface || "#f1dfd9"
    property color cOutline: colorsData.outline || "#a08d86"

    property var colorsData: ({})
    property var appList: []
    property int selectedIndex: 0

    FileView {
        path: root.homeDir + "/.local/state/quickshell/user/generated/colors.json"
        onLoaded: {
            try { root.colorsData = JSON.parse(text()); } catch (e) {}
        }
    }

    property bool searchPending: false

    function triggerSearch() {
        if (rustBackend.running) {
            searchPending = true;
            return;
        }
        rustBackend.running = true;
    }

    Process {
        id: rustBackend
        command: [root.backend, "--filter", searchInput.text]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.appList = JSON.parse(text);
                    root.selectedIndex = 0;
                } catch (e) {}
            }
        }

        onRunningChanged: {
            if (!running && root.searchPending) {
                root.searchPending = false;
                root.triggerSearch();
            }
        }
    }

    function launchApp(item) {
        Quickshell.execDetached([root.backend, "--exec", item.nome, item.exec]);
        close();
    }

    function close() {
        if (!shown) return;
        closing = true;
        shown = false;
        closeTimer.start();
    }

    Timer {
        id: closeTimer
        interval: 150
        onTriggered: root.dismissed()
    }

    Rectangle {
        id: card
        anchors.fill: parent
        color: Qt.rgba(root.cSurfaceContainer.r, root.cSurfaceContainer.g,
                       root.cSurfaceContainer.b, root.blurEnabled ? 0.5 : 1.0)
        radius: 16
        border.color: root.cOutline
        border.width: 1

        scale: root.shown ? 1.0 : 0.95
        opacity: root.shown ? 1.0 : 0.0
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
        Behavior on opacity { NumberAnimation { duration: 100 } }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 10

            Rectangle {
                Layout.fillWidth: true
                height: 42
                color: "transparent"
                border.color: searchInput.activeFocus ? root.cPrimary : "transparent"
                border.width: 1
                radius: 8

                TextInput {
                    id: searchInput
                    anchors.fill: parent
                    anchors.margins: 10
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: "Montserrat"
                    font.pixelSize: 16
                    color: root.cOnSurface
                    focus: true

                    Text {
                        text: "Buscar..."
                        color: root.cOnSurface
                        opacity: 0.4
                        font: parent.font
                        visible: !parent.text && !parent.activeFocus
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    onTextChanged: searchDebounceTimer.restart()

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) {
                            root.close();
                        } else if (event.key === Qt.Key_Down) {
                            if (root.appList.length > 0)
                                root.selectedIndex = Math.min(root.selectedIndex + 1, root.appList.length - 1);
                        } else if (event.key === Qt.Key_Up) {
                            if (root.selectedIndex > 0)
                                root.selectedIndex--;
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            if (root.appList.length > root.selectedIndex)
                                root.launchApp(root.appList[root.selectedIndex]);
                        }
                    }
                }
            }

            Timer {
                id: searchDebounceTimer
                interval: 20
                repeat: false
                onTriggered: root.triggerSearch()
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: root.cOutline
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

                delegate: Rectangle {
                    width: listView.width
                    height: 40
                    radius: 8

                    property bool isSelected: index === root.selectedIndex

                    color: isSelected
                        ? root.cPrimary
                        : (mouseArea.containsMouse
                            ? Qt.rgba(root.cOnSurface.r, root.cOnSurface.g, root.cOnSurface.b, 0.08)
                            : "transparent")

                    Behavior on color { ColorAnimation { duration: 80 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 10

                        Image {
                            source: modelData.icone_path ? "file://" + modelData.icone_path : ""
                            Layout.preferredWidth: 24
                            Layout.preferredHeight: 24
                            fillMode: Image.PreserveAspectFit
                        }

                        Text {
                            text: modelData.nome
                            font.family: "Montserrat"
                            font.pixelSize: 15
                            color: isSelected ? root.cOnPrimary : root.cOnSurface
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        id: mouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            root.selectedIndex = index;
                            root.launchApp(modelData);
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        triggerSearch();
        Qt.callLater(() => root.shown = true);
    }
}
