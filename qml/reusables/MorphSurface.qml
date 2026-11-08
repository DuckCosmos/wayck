import QtQuick
import "../"

Rectangle {
    id: root

    property bool expanded: false
    property real expandedWidth: parent ? parent.width : 0
    property real expandedHeight: parent ? parent.height : 0
    property real collapsedWidth: 160
    property real collapsedHeight: 54
    property real expandedRadius: 16
    property real collapsedRadius: 27
    property int openDuration: Motion.surfaceOpenDuration
    property int closeDuration: Motion.surfaceCloseDuration

    default property alias contentData: content.data

    width: expanded ? expandedWidth : collapsedWidth
    height: expanded ? expandedHeight : collapsedHeight
    radius: expanded ? expandedRadius : collapsedRadius
    clip: true
    antialiasing: true

    Behavior on width {
        NumberAnimation {
            duration: root.expanded ? root.openDuration : root.closeDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.expanded ? Motion.surfaceOpenCurve : Motion.surfaceCloseCurve
        }
    }

    Behavior on height {
        NumberAnimation {
            duration: root.expanded ? root.openDuration : root.closeDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.expanded ? Motion.surfaceOpenCurve : Motion.surfaceCloseCurve
        }
    }

    Behavior on radius {
        NumberAnimation {
            duration: Motion.morphDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.morphCurve
        }
    }

    Item {
        id: content
        anchors.fill: parent
        opacity: root.expanded ? 1 : 0
        enabled: root.expanded
        visible: root.expanded || opacity > 0.01

        Behavior on opacity {
            SequentialAnimation {
                PauseAnimation { duration: root.expanded ? Motion.contentRevealDelay : 0 }
                NumberAnimation {
                    duration: Motion.contentFadeDuration
                    easing.type: Easing.InOutCubic
                }
            }
        }
    }
}