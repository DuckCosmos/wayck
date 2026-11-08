import QtQuick
import Quickshell
import Quickshell.Wayland
import "../"

PanelWindow {
    id: root

    required property var modelData

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
        collapsedRadius: 9
        collapsedScale: 1

        expandedWidth: Math.min(460, Math.max(240, root.width - 48))
        expandedHeight: Math.min(260, Math.max(210, root.height - 48))
        expandedX: (root.width - expandedWidth) / 2
        expandedY: (root.height - expandedHeight) / 2
        expandedRadius: 20
        expandedScale: 1

        color: Theme.surfaceContainer
        border.width: 1
        border.color: Theme.outline
        antialiasing: true

        PlayerExpandedSurface {
            anchors.fill: parent
            onCloseRequested: MorphController.close()
        }

        onProgressChanged: {
            if (MorphController.closing && progress <= 0.001)
                Qt.callLater(MorphController.finish)
        }
    }
}
