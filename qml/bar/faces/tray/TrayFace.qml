import QtQuick
import Quickshell
import "../../../"

BarCard {
    id: root

    property var items: TrayController.items
    readonly property bool debug: Quickshell.env("WAYCK_DEBUG") === "1"
    signal expandRequested(var sourceItem, var surfaceData, var windowRef)

    property var activeTrayItem: null
    property var activeAnchor: null

    readonly property int iconSize: 30
    readonly property int itemSpacing: 2

    horizontalPadding: 8
    verticalPadding: 2
    contentSpacing: 0
    minimumHeight: 0

    function openMenu(item, anchor, immediate) {
        if (debug)
            console.log("[WAYCK INPUT] tray menu request:",
                item ? (item.title || item.id) : "null",
                "immediate=", immediate,
                "anchor=", !!anchor)

        if (!item || !item.hasMenu || !item.menu) {
            if (debug)
                console.log("[WAYCK INPUT] tray icon has no native menu")
            return
        }

        if (MorphController.active || MorphController.opening) {
            if (MorphController.surfaceId === "tray"
                    && MorphController.surfaceData === item.menu) {
                return
            }

            return
        }

        activeAnchor = anchor
        activeTrayItem = item

        if (immediate) {
            hoverOpenTimer.stop()
            requestExpand("click")
        } else {
            hoverOpenTimer.restart()
        }
    }

    function requestExpand(reason): void {
        if (!activeAnchor || !activeTrayItem || !activeTrayItem.menu) {
            if (debug)
                console.log("[WAYCK INPUT] tray request missing anchor/menu")
            return
        }

        if (debug)
            console.log("[WAYCK INPUT] tray emit expandRequested:",
                reason, activeTrayItem.title || activeTrayItem.id)

        expandRequested(activeAnchor, activeTrayItem.menu, QsWindow.window)
    }

    function cancelPendingOpen() {
        if (!MorphController.active && !MorphController.opening)
            hoverOpenTimer.stop()
    }

    Timer {
        id: hoverOpenTimer

        interval: 200
        repeat: false

        onTriggered: {
            if (root.debug)
                console.log("[WAYCK INPUT] tray hover dwell elapsed:",
                    root.activeTrayItem ? (root.activeTrayItem.title || root.activeTrayItem.id) : "null")

            if (root.activeTrayItem
                    && root.activeTrayItem.hasMenu
                    && root.activeAnchor
                    && !MorphController.active
                    && !MorphController.opening) {
                root.requestExpand("hover dwell")
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

                onMenuRequested: (item, anchor, immediate) =>
                    root.openMenu(item, anchor, immediate)

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
