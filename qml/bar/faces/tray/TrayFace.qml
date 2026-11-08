import QtQuick
import "../../../"

BarCard {
    id: root

    property var items: TrayController.items
    property var activeTrayItem: null
    property var activeAnchor: null

    signal expandRequested(var sourceItem, var surfaceData)

    readonly property int iconSize: 30
    readonly property int itemSpacing: 2

    horizontalPadding: 8
    verticalPadding: 2
    contentSpacing: 0
    minimumHeight: 0

    function openMenu(item, anchor) {
        if (!item || !item.hasMenu || MorphController.active)
            return

        activeAnchor = anchor
        activeTrayItem = item
        hoverOpenTimer.restart()
    }

    function cancelPendingOpen() {
        if (!MorphController.active)
            hoverOpenTimer.stop()
    }

    Timer {
        id: hoverOpenTimer

        interval: 200
        repeat: false

        onTriggered: {
            if (root.activeTrayItem
                    && root.activeTrayItem.hasMenu
                    && root.activeAnchor
                    && !MorphController.active) {
                root.expandRequested(root.activeAnchor, root.activeTrayItem.menu)
            }
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

                onMenuRequested: (item, anchor) => root.openMenu(item, anchor)
                onPointerLeft: root.cancelPendingOpen()
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
