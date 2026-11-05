import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../services"
import "."

Item {
    id: root

    property color cPrimary: "#ffb59b"
    property color cOnPrimary: "#55200a"
    property color cSurfaceContainer: "#322824"
    property color cOnSurface: "#f1dfd9"
    property color cOutline: "#a08d86"

    property var items: TrayService.items
    property var hostWindow: QsWindow.window

    readonly property int iconSize: 34
    readonly property int itemSpacing: 5

    implicitWidth: items.length > 0
        ? items.length * iconSize + (items.length - 1) * itemSpacing
        : 0
    implicitHeight: items.length > 0 ? iconSize : 0
    width: implicitWidth
    height: implicitHeight

    function showMenu(trayItem, iconItem) {
        if (!trayItem.hasMenu || !root.hostWindow)
            return

        const position = root.hostWindow.itemPosition(iconItem)

        trayItem.display(
            root.hostWindow,
            Math.round(position.x + iconItem.width / 2),
            Math.round(position.y + iconItem.height)
        )
    }

    Row {
        anchors.fill: parent
        spacing: root.itemSpacing

        Repeater {
            model: root.items

            delegate: BarCard {
                id: trayCard
                required property var modelData
                property var trayItem: modelData
                property bool iconFailed: false

                width: root.iconSize
                height: root.iconSize
                implicitWidth: root.iconSize
                implicitHeight: root.iconSize
                horizontalPadding: 6
                verticalPadding: 5

                cPrimary: root.cPrimary
                cOnPrimary: root.cOnPrimary
                cSurfaceContainer: root.cSurfaceContainer
                cOnSurface: root.cOnSurface
                cOutline: root.cOutline

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    id: iconArea

                    Image {
                        anchors.fill: parent
                        source: trayCard.trayItem.icon
                        fillMode: Image.PreserveAspectFit
                        sourceSize.width: 24
                        sourceSize.height: 24
                        asynchronous: true

                        onStatusChanged: {
                            if (status === Image.Error)
                                trayCard.iconFailed = true
                            else if (status === Image.Ready)
                                trayCard.iconFailed = false
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: (trayCard.trayItem.title || trayCard.trayItem.id || "?")
                            .charAt(0).toUpperCase()
                        color: root.cOnSurface
                        font.pixelSize: 12
                        font.bold: true
                        visible: trayCard.iconFailed || trayCard.trayItem.icon === ""
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

                        onClicked: function(mouse) {
                            const item = trayCard.trayItem

                            if (mouse.button === Qt.LeftButton) {
                                if (item.onlyMenu && item.hasMenu)
                                    root.showMenu(item, iconArea)
                                else
                                    item.activate()
                            } else if (mouse.button === Qt.RightButton) {
                                root.showMenu(item, iconArea)
                            } else if (mouse.button === Qt.MiddleButton) {
                                item.secondaryActivate()
                            }
                        }
                    }
                }
            }
        }
    }
}
