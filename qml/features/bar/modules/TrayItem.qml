import QtQuick
import QtQuick.Layouts
import Quickshell
import "."
import "../../../core"

BarCard {
    id: root

    required property var trayItem

    signal menuRequested(var item, var anchor)
    signal pointerLeft()

    property bool iconFailed: false

    horizontalPadding: 6
    verticalPadding: 6
    showBackground: false
    showBorder: false

    Item {
        id: iconArea

        anchors.fill: parent

        Image {
            anchors.fill: parent

            source: root.trayItem.icon
            fillMode: Image.PreserveAspectFit

            sourceSize.width: 24
            sourceSize.height: 24

            asynchronous: true

            onStatusChanged: {
                if (status === Image.Error)
                    root.iconFailed = true
                else if (status === Image.Ready)
                    root.iconFailed = false
            }
        }

        Text {
            anchors.centerIn: parent

            text: (root.trayItem.title || root.trayItem.id || "?")
                .charAt(0).toUpperCase()

            color: Theme.onSurface
            font.pixelSize: 12
            font.bold: true

            visible: root.iconFailed || root.trayItem.icon === ""
        }

        MouseArea {
            anchors.fill: parent

            hoverEnabled: true
            acceptedButtons: Qt.LeftButton

            onEntered: {
                if (root.trayItem.hasMenu)
                    root.menuRequested(root.trayItem, iconArea)
            }

            onExited: {
                root.pointerLeft()
            }

            onClicked: {
                root.trayItem.activate()
            }
        }
    }
}