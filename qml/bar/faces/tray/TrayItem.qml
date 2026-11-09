import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../"

BarCard {
    id: root

    required property var trayItem

    signal menuRequested(var item, var anchor, bool immediate)
    signal pointerLeft()

    property bool iconFailed: false
    readonly property bool debug: Quickshell.env("WAYCK_DEBUG") === "1"
    readonly property var interactionAnchor: iconArea

    horizontalPadding: 6
    verticalPadding: 6
    showBackground: false
    showBorder: false

    Item {
        id: iconArea

        Layout.fillWidth: true
        Layout.fillHeight: true

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

            color: Theme.surfaceForeground
            font.pixelSize: 12
            font.bold: true

            visible: root.iconFailed || root.trayItem.icon === ""
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: false
            acceptedButtons: Qt.LeftButton
            cursorShape: root.trayItem.hasMenu
                ? Qt.PointingHandCursor
                : Qt.ArrowCursor

            onClicked: {
                if (root.debug)
                    console.log("[WAYCK INPUT] tray MouseArea clicked:",
                        root.trayItem.title || root.trayItem.id,
                        "hasMenu=", root.trayItem.hasMenu)

                if (root.trayItem.hasMenu)
                    root.menuRequested(root.trayItem, iconArea, true)
                else
                    root.trayItem.activate()
            }
        }
    }
}
