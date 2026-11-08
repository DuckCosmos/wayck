import QtQuick
import Quickshell
import Quickshell.Wayland
import "../"

PanelWindow {
    id: root

    // Variants injects modelData after creating its delegate.
    property var modelData: null

    readonly property bool traySurface: MorphController.surfaceId === "tray"
    readonly property real sourceX: MorphController.sourceGlobalX - (modelData ? modelData.x : 0)
    readonly property real sourceY: MorphController.sourceGlobalY - (modelData ? modelData.y : 0)

    readonly property real targetWidth: traySurface
        ? Math.min(Math.max(240, surfaceContent.implicitWidth || 256), Math.max(1, width - 24))
        : Math.min(460, Math.max(1, width - 48))

    readonly property real targetHeight: traySurface
        ? Math.min(Math.max(72, surfaceContent.implicitHeight || 72), Math.max(1, height - 24))
        : Math.min(260, Math.max(1, height - 48))

    readonly property real targetX: Math.max(12, Math.min(
        sourceX + MorphController.sourceWidth / 2 - targetWidth / 2,
        width - targetWidth - 12
    ))

    readonly property real targetY: Math.max(12, Math.min(
        BarConfig.position === "bottom"
            ? sourceY + MorphController.sourceHeight - targetHeight
            : sourceY,
        height - targetHeight - 12
    ))

    color: "transparent"
    screen: modelData
    visible: MorphController.active && MorphController.targetScreen === modelData

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.namespace: "wayck-morph-overlay"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    mask: Region {
        item: surface
    }

    MorphSurface {
        id: surface

        snapshotSource: MorphController.snapshotUrl
        progress: MorphController.progress
        expanded: !MorphController.closing

        collapsedX: MorphController.sourceGlobalX - (root.modelData ? root.modelData.x : 0)
        collapsedY: MorphController.sourceGlobalY - (root.modelData ? root.modelData.y : 0)
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
            onHoveredChanged: MorphController.setSurfaceHovered(hovered)
        }

        onProgressChanged: {
            MorphController.syncAnimationProgress(progress)

            if (MorphController.closing && progress <= 0.001)
                Qt.callLater(MorphController.finish)
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
