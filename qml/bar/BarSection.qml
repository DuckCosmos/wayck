import QtQuick
import Quickshell
import "../"

Row {
    id: root

    property var model: []
    property var hiddenIds: ({})
    property real compactness: 0
    property string sectionName: ""
    property int firstOrder: 0
    readonly property bool debug: Quickshell.env("WAYCK_DEBUG") === "1"

    signal metricsChanged()
    signal surfaceRequested(var sourceItem, string surfaceId, var surfaceData, var windowRef)

    spacing: 6

    function slots() {
        const result = []

        for (let i = 0; i < repeater.count; i++) {
            const slot = repeater.itemAt(i)

            if (slot)
                result.push(slot)
        }

        return result
    }

    Repeater {
        id: repeater

        model: root.model

        delegate: BarModule {
            required property var modelData
            required property int index

            moduleId: modelData
            sectionName: root.sectionName
            order: root.firstOrder + index
            compactness: root.compactness
            shown: root.hiddenIds[modelData] !== true

            y: (root.height - height) / 2

            onImplicitWidthChanged: root.metricsChanged()
            onSurfaceRequested: (sourceItem, surfaceId, surfaceData, windowRef) => {
                if (root.debug)
                    console.log("[WAYCK INPUT] BarSection encaminhando", surfaceId)
                root.surfaceRequested(sourceItem, surfaceId, surfaceData, windowRef)
            }
            Component.onCompleted: root.metricsChanged()
        }
    }
}
