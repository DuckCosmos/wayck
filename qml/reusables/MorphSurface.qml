import QtQuick
import "../"

Rectangle {
    id: root

    // A single surface whose geometry is interpolated as one motion value.
    // Keep this item inside the same QQuickWindow as its source and destination.
    property bool expanded: false

    property real collapsedX: parent ? (parent.width - collapsedWidth) / 2 : 0
    property real collapsedY: parent ? (parent.height - collapsedHeight) / 2 : 0
    property real expandedX: parent ? (parent.width - expandedWidth) / 2 : 0
    property real expandedY: parent ? (parent.height - expandedHeight) / 2 : 0

    property real collapsedWidth: 160
    property real collapsedHeight: 54
    property real expandedWidth: parent ? parent.width : 0
    property real expandedHeight: parent ? parent.height : 0

    property real collapsedRadius: 27
    property real expandedRadius: 16
    property real collapsedScale: 0.96
    property real expandedScale: 1.0

    property int openDuration: Motion.surfaceOpenDuration
    property int closeDuration: Motion.surfaceCloseDuration
    property url snapshotSource: ""

    // Animating one normalized progress keeps x/y/width/height/radius/scale
    // phase-locked and allows a running morph to be retargeted safely.
    property real progress: expanded ? 1 : 0

    default property alias contentData: content.data

    readonly property real contentProgress: Math.max(0, Math.min(1, (progress - 0.18) / 0.82))

    x: collapsedX + (expandedX - collapsedX) * progress
    y: collapsedY + (expandedY - collapsedY) * progress
    width: collapsedWidth + (expandedWidth - collapsedWidth) * progress
    height: collapsedHeight + (expandedHeight - collapsedHeight) * progress
    radius: collapsedRadius + (expandedRadius - collapsedRadius) * progress
    scale: collapsedScale + (expandedScale - collapsedScale) * progress

    clip: true
    antialiasing: true
    transformOrigin: Item.Center

    Behavior on progress {
        NumberAnimation {
            duration: root.expanded ? root.openDuration : root.closeDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.expanded ? Motion.surfaceOpenCurve : Motion.surfaceCloseCurve
        }
    }

    Image {
        parent: root
        anchors.fill: parent
        z: 0
        source: root.snapshotSource
        fillMode: Image.Stretch
        asynchronous: true
        visible: root.snapshotSource != ""
        opacity: 1 - root.contentProgress
    }

    Item {
        id: content
        anchors.fill: parent
        z: 1
        opacity: root.contentProgress
        enabled: root.progress > 0.98
        visible: root.progress > 0.01

        Behavior on opacity {
            NumberAnimation {
                duration: Motion.contentFadeDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.contentCurve
            }
        }
    }
}
