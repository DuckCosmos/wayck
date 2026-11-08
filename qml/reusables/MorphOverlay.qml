import QtQuick
import Quickshell
import Quickshell.Wayland
import "../"

PanelWindow {
    id: root

    // Variants injects monitor data after creating the delegate.
    property var monitor: null

    readonly property bool traySurface: MorphController.surfaceId === "tray"
    readonly property bool ownsSurface: MorphController.active
        && monitor !== null
        && MorphController.targetScreen !== null
        && monitor.name === MorphController.targetScreen.name
    readonly property bool debug: Quickshell.env("WAYCK_DEBUG") === "1"

    readonly property real sourceX:
        MorphController.sourceGlobalX - (monitor ? monitor.x : 0)

    readonly property real sourceY:
        MorphController.sourceGlobalY - (monitor ? monitor.y : 0)

    readonly property real targetWidth: traySurface
        ? Math.min(
            Math.max(240, surfaceContent.implicitWidth || 256),
            Math.max(1, width - 24)
        )
        : Math.min(460, Math.max(240, width - 48))

    readonly property real targetHeight: traySurface
        ? Math.min(
            Math.max(72, surfaceContent.implicitHeight || 72),
            Math.max(1, height - 24)
        )
        : Math.min(260, Math.max(210, height - 48))

    readonly property real targetX: Math.max(0, Math.min(
        sourceX + MorphController.sourceWidth / 2 - targetWidth / 2,
        width - targetWidth
    ))

    // Keep the expanded tray panel outside the icon lane so the overlay never
    // covers the next icons while the pointer travels across the tray.
    readonly property real targetY: Math.max(8, Math.min(
        BarConfig.position === "bottom"
            ? sourceY - targetHeight - 8
            : sourceY + MorphController.sourceHeight + 8,
        height - targetHeight - 8
    ))

    color: "transparent"
    screen: monitor
    visible: ownsSurface
    exclusionMode: ExclusionMode.Ignore

    onVisibleChanged: {
        if (debug)
            console.log("[WAYCK MORPH OVERLAY] visible=", visible,
                "monitor=", monitor ? monitor.name : "null",
                "surface=", MorphController.surfaceId)
    }

    Component.onCompleted: {
        if (debug)
            console.log("[WAYCK MORPH OVERLAY] instanciado em",
                monitor ? monitor.name : "monitor nulo")
    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.namespace: "wayck-morph-overlay"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    mask: Region {
        item: surface

        // Keep the collapsed player anchor in the overlay input region while
        // the morph moves away from it. This prevents a false hover exit.
        Region {
            item: sourceHoverRegion
        }
    }

    // The player source remains a hover-safe area during the morph. Once
    // the pointer actually leaves this anchor, normal hover-close behavior resumes.
    Item {
        id: sourceHoverRegion

        x: root.sourceX
        y: root.sourceY
        width: MorphController.sourceWidth
        height: MorphController.sourceHeight
        visible: MorphController.active && MorphController.surfaceId === "player"

        HoverHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

            onHoveredChanged: {
                if (MorphController.debug)
                    console.log("[WAYCK MORPH] player source hotspot hover:", hovered)

                if (MorphController.sourceItem)
                    MorphController.setSourceHovered(MorphController.sourceItem, hovered)
            }
        }
    }

    MorphSurface {
        id: surface

        snapshotSource: MorphController.snapshotUrl
        snapshotOpacity: MorphController.snapshotOpacity
        progress: MorphController.progress
        expanded: !MorphController.closing

        collapsedX: MorphController.sourceGlobalX - (root.monitor ? root.monitor.x : 0)
        collapsedY: MorphController.sourceGlobalY - (root.monitor ? root.monitor.y : 0)
        collapsedWidth: MorphController.sourceWidth
        collapsedHeight: MorphController.sourceHeight
        collapsedRadius: root.traySurface ? 7 : 9
        collapsedScale: 1

        expandedWidth: root.targetWidth
        expandedHeight: root.targetHeight
        expandedX: root.targetX
        expandedY: root.targetY
        expandedRadius: root.traySurface ? 14 : 20
        expandedScale: 1

        color: Theme.surfaceContainer
        border.width: 1
        border.color: Theme.outline
        antialiasing: true

        Loader {
            id: surfaceContent
            anchors.fill: parent
            sourceComponent: !MorphController.active
                ? null
                : (root.traySurface ? trayContent : playerContent)
        }

        HoverHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onHoveredChanged: {
                if (MorphController.debug)
                    console.log("[WAYCK MORPH] overlay surface hover:", hovered)
                MorphController.setSurfaceHovered(hovered)
            }
        }

        onProgressChanged: {
            MorphController.syncAnimationProgress(progress)

            if (MorphController.closing && progress <= 0.001) {
                Qt.callLater(function() {
                    if (MorphController.closing && MorphController.progress <= 0.001)
                        MorphController.finish()
                })
            }
        }
    }

    Component {
        id: playerContent

        PlayerExpandedSurface {
            onCloseRequested: MorphController.close()
        }
    }

    Component {
        id: trayContent

        TrayExpandedSurface {
            menu: MorphController.surfaceData
            onCloseRequested: MorphController.close()
        }
    }
}
