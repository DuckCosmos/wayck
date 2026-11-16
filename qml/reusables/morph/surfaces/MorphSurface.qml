import QtQuick

Item {
    id: root

    // Reference back to the single Morph engine that owns this surface.
    property var morph: null

    // Geometry contract consumed by Morph.qml.
    property string morphWidthMode: "available"
    property real morphMinWidth: 240
    property real morphMaxWidth: 460
    property real morphWidthMargin: 48
    property real morphPreferredWidth: 0
    property real morphWidthAvailableFloor: 1

    property string morphHeightMode: "available"
    property real morphMinHeight: 210
    property real morphMaxHeight: 260
    property real morphHeightMargin: 48
    property real morphPreferredHeight: 0
    property real morphHeightAvailableFloor: 1

    property real morphCollapsedRadius: 9
    property real morphExpandedRadius: 20

    // Some surfaces keep their source anchor active for hover/retargeting.
    property bool morphSourceHoverEnabled: true
    property bool morphRetargetable: false

    function resolvedTargetWidth(containerWidth): real {
        if (morphWidthMode === "content") {
            const desired = implicitWidth || morphPreferredWidth
            const available = Math.max(
                morphWidthAvailableFloor,
                containerWidth - morphWidthMargin
            )

            return Math.min(Math.max(morphMinWidth, desired), available)
        }

        return Math.min(
            morphMaxWidth,
            Math.max(morphMinWidth, containerWidth - morphWidthMargin)
        )
    }

    function resolvedTargetHeight(containerHeight): real {
        if (morphHeightMode === "content") {
            const desired = implicitHeight || morphPreferredHeight
            const available = Math.max(
                morphHeightAvailableFloor,
                containerHeight - morphHeightMargin
            )

            return Math.min(Math.max(morphMinHeight, desired), available)
        }

        return Math.min(
            morphMaxHeight,
            Math.max(morphMinHeight, containerHeight - morphHeightMargin)
        )
    }
}
