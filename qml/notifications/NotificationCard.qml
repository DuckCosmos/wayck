
import QtQuick
import QtQuick.Layouts
import "../"

Item {
    id: root

    required property var notification

    property int cornerRadius: 12
    property int horizontalPadding: 12
    property int topPadding: 10
    property int bottomPadding: 15
    property int contentSpacing: 12

    implicitWidth: 280
    implicitHeight: 80

    Rectangle {
        anchors.fill: parent
        radius: root.cornerRadius

        color: Qt.darker(Theme.surfaceContainer, 1.75)

        antialiasing: true
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        radius: root.cornerRadius

        border.width: 1
        border.color: Qt.darker(Theme.outline, 1.15)

        antialiasing: true
    }

    Timer {
        interval: 5000
        running: true
        repeat: false

        onTriggered: {
            SysNotif.removeNotification(root.notification.id)
        }
    }

    RowLayout {
        anchors.fill: parent

        anchors.leftMargin: root.horizontalPadding
        anchors.rightMargin: root.horizontalPadding
        anchors.topMargin: root.topPadding
        anchors.bottomMargin: root.bottomPadding

        spacing: root.contentSpacing

        Image {
            source: root.notification.image
                ? root.notification.image
                : root.notification.appIcon

            Layout.preferredWidth: 30
            Layout.preferredHeight: 30
            Layout.alignment: Qt.AlignVCenter

            fillMode: Image.PreserveAspectFit
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumWidth: 0

            spacing: 5

            Text {
                text: root.notification.summary
                font.pixelSize: 15
                font.bold: true
                color: Theme.primary

                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            Text {
                text: root.notification.body
                font.pixelSize: 12
                color: Theme.onSurface

                Layout.fillWidth: true
                maximumLineCount: 2
                elide: Text.ElideRight
            }
        }
    }

    property bool entered: false

    opacity: entered ? 1 : 0

    Component.onCompleted: entered = true

    Behavior on opacity {
        NumberAnimation {
            duration: 250
            easing.type: Easing.OutCubic
        }
    }
}
