import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../"
import "."

BarCard {
    id: root

    property var items: TrayController.items
    property var hostWindow: QsWindow.window

    property var activeTrayItem: null
    property var activeAnchor: null

    property bool menuVisible: false
    property bool popupVisible: false
    property bool menuHovered: false

    readonly property int iconSize: 30
    readonly property int itemSpacing: 2

    horizontalPadding: 8
    verticalPadding: 2
    contentSpacing: 0
    minimumHeight: 0

    function openMenu(item, anchor) {
        if (!item || !item.hasMenu)
            return

        closeTimer.stop()
        hideTimer.stop()

        activeAnchor = anchor
        activeTrayItem = item

        popupVisible = true
        menuVisible = true
    }

    function scheduleClose() {
        closeTimer.restart()
    }

    function closeMenu() {
        if (!menuHovered) {
            menuVisible = false
            hideTimer.restart()
        }
    }

    Timer {
        id: closeTimer

        interval: 180
        repeat: false

        onTriggered: root.closeMenu()
    }

    Timer {
        id: hideTimer

        interval: 700
        repeat: false

        onTriggered: {
            if (!root.menuVisible)
                root.popupVisible = false
        }
    }

    Row {
        spacing: root.itemSpacing

        Repeater {
            model: root.items

            delegate: TrayItem {
                required property var modelData

                trayItem: modelData

                width: root.iconSize
                height: root.iconSize

                onMenuRequested: (item, anchor) => {
                    root.openMenu(item, anchor)
                }

                onPointerLeft: {
                    root.scheduleClose()
                }
            }
        }
    }

    PopupWindow {
        id: menuPopup

        anchor.item: root.activeAnchor

        anchor.rect.x: root.activeAnchor
            ? (root.activeAnchor.width - width) / 2
            : 0

        anchor.rect.y: root.activeAnchor
            ? root.activeAnchor.height
            : 0

        implicitWidth: menuCard.implicitWidth
        implicitHeight: menuCard.implicitHeight

        visible: root.popupVisible
        color: "transparent"

        TrayMenu {
            id: menuCard

            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter

            menu: root.activeTrayItem
                ? root.activeTrayItem.menu
                : null

            menuVisible: root.menuVisible

            onPointerEntered: {
                root.menuHovered = true
                closeTimer.stop()
            }

            onPointerExited: {
                root.menuHovered = false
                root.scheduleClose()
            }

            onCloseRequested: {
                root.menuHovered = false
                root.menuVisible = false
                hideTimer.restart()
            }
        }
    }

    implicitWidth: root.items.length > 0
        ? root.items.length * root.iconSize
            + (root.items.length - 1) * root.itemSpacing
            + root.horizontalPadding * 2
        : 0

    implicitHeight: root.items.length > 0
        ? root.iconSize + root.verticalPadding * 2
        : 0
}