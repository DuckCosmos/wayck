import QtQuick
import QtQuick.Layouts
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

    property var appList: []
    property int selectedIndex: 0

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
        interval: Motion.surfaceCloseDuration + 40
        onTriggered: root.dismissed()
    }

    MorphSurface {
        id: card
        anchors.centerIn: parent
        expanded: root.shown
        expandedWidth: parent.width
        expandedHeight: parent.height
        collapsedWidth: Math.min(190, parent.width * 0.55)
        collapsedHeight: 54
        expandedRadius: 16
        collapsedRadius: 27

        color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g,
                       Theme.surfaceContainer.b, root.blurEnabled ? 0.5 : 1.0)
        border.color: Theme.outline
        border.width: 1

        LayoutMirroring.enabled: I18n.rtl
        LayoutMirroring.childrenInherit: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 10

            Rectangle {
                Layout.fillWidth: true
                height: 42
                color: "transparent"
                border.color: searchInput.activeFocus ? Theme.primary : "transparent"
                border.width: 1
                radius: 8

                TextInput {
                    id: searchInput
                    anchors.fill: parent
                    anchors.margins: 10
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: Qt.application.font.family
                    font.pixelSize: 16
                    color: Theme.onSurface
                    focus: true

                    Text {
                        text: I18n.t("launcher.search")
                        color: Theme.onSurface
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
                        if (event.key === Qt.Key_Escape) {
                            root.close();
                        } else if (event.key === Qt.Key_Down) {
                            if (root.appList.length > 0)
                                root.selectedIndex = Math.min(root.selectedIndex + 1, root.appList.length - 1);
                                event.accepted = true
                        } else if (event.key === Qt.Key_Up) {
                            if (root.selectedIndex > 0)
                                root.selectedIndex--;
                                event.accepted = true
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            if (root.appList.length > root.selectedIndex)
                                root.launchApp(root.appList[root.selectedIndex]);
                                event.accepted = true
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

                    property bool isSelected: index === root.selectedIndex

                    color: isSelected
                        ? Theme.primary
                        : (mouseArea.containsMouse
                            ? Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.08)
                            : "transparent")

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
                            source: modelData.icone_path ? "file://" + modelData.icone_path : ""
                            Layout.preferredWidth: 24
                            Layout.preferredHeight: 24
                            fillMode: Image.PreserveAspectFit
                        }

                        Text {
                            text: modelData.nome
                            font.family: Qt.application.font.family
                            font.pixelSize: 15
                            color: isSelected ? Theme.onPrimary : Theme.onSurface
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
