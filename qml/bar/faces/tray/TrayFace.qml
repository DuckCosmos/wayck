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
        if (!item || !item.hasMenu || !item.menu || !anchor)
            return

        const sameAnchor = activeTrayItem === item && activeAnchor === anchor

        if (sameAnchor) {
            if (MorphController.active && MorphController.surfaceId === "tray"
                    && MorphController.closing) {
                hoverOpenTimer.stop()
                MorphController.retarget(anchor, "tray", item.menu, QsWindow.window)
            }
            return
        }

        if (debug)
            console.log("[WAYCK INPUT] tray focus:", item.title || item.id,
                "immediate=", immediate)

        activeAnchor = anchor
        activeTrayItem = item

        // Once a tray surface exists, changing icons retargets the same surface.
        // Its progress never returns to zero; only its geometry and menu data move.
        if (MorphController.active && MorphController.surfaceId === "tray") {
            hoverOpenTimer.stop()
            MorphController.retarget(anchor, "tray", item.menu, QsWindow.window)
            return
        }

        if (MorphController.active || MorphController.opening)
            return

        if (immediate) {
            hoverOpenTimer.stop()
            requestExpand("click")
        } else {
            hoverOpenTimer.restart()
        }
    }

    function updateHoveredMenu(position): void {
        // The row-level HoverHandler reports coordinates in trayRow space.
        let hit = trayRow.childAt(position.x, position.y)

        // childAt may return an inner visual item; climb to the TrayItem delegate.
        while (hit && hit !== trayRow && hit.trayItem === undefined)
            hit = hit.parent

        if (!hit || hit === trayRow || hit.trayItem === undefined)
            return

        const item = hit.trayItem

        if (!item.hasMenu || !item.menu) {
            hoverOpenTimer.stop()
            if (!MorphController.active) {
                activeTrayItem = null
                activeAnchor = null
            } else if (debug) {
                console.log("[WAYCK INPUT] tray item sem menu; mantendo superfície atual até sair da região")
            }
            return
        }

        root.openMenu(item, hit.interactionAnchor, false)
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
        id: trayRow
        spacing: root.itemSpacing

        HoverHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

            onHoveredChanged: {
                MorphController.setSourceHovered(root, hovered)

                if (root.debug)
                    console.log("[WAYCK INPUT] tray row hover:", hovered)

                if (hovered)
                    root.updateHoveredMenu(point.position)
                else
                    root.cancelPendingOpen()
            }

            onPointChanged: {
                if (hovered)
                    root.updateHoveredMenu(point.position)
            }
        }

        Repeater {
            model: root.items

            delegate: TrayItem {
                required property var modelData

                trayItem: modelData

                width: root.iconSize
                height: root.iconSize

                onMenuRequested: (item, anchor, immediate) =>
                    root.openMenu(item, anchor, immediate)
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
